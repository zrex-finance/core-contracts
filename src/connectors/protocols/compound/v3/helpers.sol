// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../lib/UniversalERC20.sol";

import { Basic } from "../../../common/base.sol";
import { IComet } from "./interface.sol";

abstract contract CompoundV3Helpers is Basic {
	using UniversalERC20 for IERC20;

	struct BorrowWithdrawParams {
		address market;
		address token;
		address from;
		address to;
		uint256 amount;
	}

	struct BuyCollateralData {
		address market;
		address sellToken;
		address buyAsset;
		uint256 unitamount;
		uint256 baseSellamount;
	}

	enum Action {
		REPAY,
		DEPOSIT
	}

	function getBaseToken(address market) internal view returns (address baseToken) {
		baseToken = IComet(market).baseToken();
	}

	function _borrow(BorrowWithdrawParams memory params) internal returns (uint256 amount) {
		amount = params.amount;

		require(
			params.market != address(0) &&
				params.token != address(0) &&
				params.to != address(0),
			"invalid market/token/to address"
		);

		params.from = params.from == address(0) 
			? address(this) 
			: params.from;

		require(IComet(params.market).balanceOf(params.from) == 0,"borrow-disabled-when-supplied-base");

		uint256 initialBalance = IComet(params.market).borrowBalanceOf(params.from);

		IComet(params.market).withdrawFrom(
			params.from,
			params.to,
			params.token,
			amount
		);

		uint256 finalBalance = IComet(params.market).borrowBalanceOf(params.from);
		amount = finalBalance - initialBalance;
	}

	function _withdraw(BorrowWithdrawParams memory params) internal returns (uint256 amount) {
		amount = params.amount;

		require(
			params.market != address(0) &&
				params.token != address(0) &&
				params.to != address(0),
			"invalid market/token/to address"
		);

		params.from = params.from == address(0) 
			? address(this) 
			: params.from;

		uint256 initialBalance = _getAccountSupplyBalanceOfAsset(params.from,params.market,params.token);

		if (params.token == getBaseToken(params.market)) {
			//if there are supplies, ensure withdrawn amount is not greater than supplied i.e can't borrow using withdraw.
			if (amount == type(uint).max) {
				amount = initialBalance;
			} else {
				require(amount <= initialBalance,"withdraw-amount-greater-than-supplies");
			}

			//if borrow balance > 0, there are no supplies so no withdraw, borrow instead.
			require(IComet(params.market).borrowBalanceOf(params.from) == 0,"withdraw-disabled-for-zero-supplies");
		} else {
			amount = amount == type(uint).max 
				? initialBalance 
				: amount;
		}

		IComet(params.market).withdrawFrom(params.from,params.to,params.token,amount);

		uint256 finalBalance = _getAccountSupplyBalanceOfAsset(params.from,params.market,params.token);
		amount = initialBalance - finalBalance;
	}

	function _getAccountSupplyBalanceOfAsset(
		address account,
		address market,
		address asset
	) internal returns (uint256 balance) {
		if (asset == getBaseToken(market)) {
			//balance in base
			balance = IComet(market).balanceOf(account);
		} else {
			//balance in asset denomination
			balance = uint256(
				IComet(market).userCollateral(account, asset).balance
			);
		}
	}

	function _calculateFromAmount(
		address market,
		address token,
		address src,
		uint256 amount,
		Action action
	) internal view returns (uint256) {
		if (amount == type(uint).max) {
			uint256 allowance = IERC20(token).allowance(src, market);
			uint256 balance;

			if (action == Action.REPAY) {
				balance = IComet(market).borrowBalanceOf(src);
			} else if (action == Action.DEPOSIT) {
				balance = IERC20(token).balanceOf(src);
			}

			amount = balance < allowance ? balance : allowance;
		}

		return amount;
	}

	function _buyCollateral(BuyCollateralData memory params) internal {
		uint256 sellAmount = params.baseSellamount;
		require(
			params.market != address(0) && params.buyAsset != address(0),
			"invalid market/token address"
		);
		require(params.sellToken == getBaseToken(params.market),"invalid-sell-token");

		if (sellAmount == type(uint).max) {
			sellAmount = IERC20(params.sellToken).balanceOf(address(this));
		}

		uint256 slippageAmount = convert18ToDec(
			IERC20(params.buyAsset).universalDecimals(),
			params.unitamount * convertTo18(IERC20(params.sellToken).universalDecimals(),sellAmount)
		);

		uint256 initialCollBalance = IERC20(params.buyAsset).balanceOf(address(this));

		IERC20(params.sellToken).universalApprove(params.market, sellAmount);
		IComet(params.market).buyCollateral(
			params.buyAsset,
			slippageAmount,
			sellAmount,
			address(this)
		);

		uint256 finalCollBalance = IERC20(params.buyAsset).balanceOf(
			address(this)
		);

		uint256 buyamount = finalCollBalance - initialCollBalance;
		require(slippageAmount <= buyamount, "too much slippage");
	}
}
