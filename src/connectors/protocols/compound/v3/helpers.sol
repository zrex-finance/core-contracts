// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../../../common/interfaces.sol";
import { Basic } from "../../../common/base.sol";
import { CometInterface } from "./interface.sol";

abstract contract CompoundV3Helpers is Basic {
	struct BorrowWithdrawParams {
		address market;
		address token;
		address from;
		address to;
		uint256 amt;
	}

	struct BuyCollateralData {
		address market;
		address sellToken;
		address buyAsset;
		uint256 unitAmt;
		uint256 baseSellAmt;
	}

	enum Action {
		REPAY,
		DEPOSIT
	}

	function getBaseToken(address market)
		internal
		view
		returns (address baseToken)
	{
		baseToken = CometInterface(market).baseToken();
	}

	function _borrow(BorrowWithdrawParams memory params)
		internal
		returns (uint256 amt)
	{
		uint256 amt_ = params.amt;

		require(
			params.market != address(0) &&
				params.token != address(0) &&
				params.to != address(0),
			"invalid market/token/to address"
		);
		bool isEth = params.token == ethAddr;
		address token_ = isEth ? wethAddr : params.token;

		TokenInterface tokenContract = TokenInterface(token_);

		params.from = params.from == address(0) ? address(this) : params.from;

		require(
			CometInterface(params.market).balanceOf(params.from) == 0,
			"borrow-disabled-when-supplied-base"
		);

		uint256 initialBal = CometInterface(params.market).borrowBalanceOf(
			params.from
		);

		CometInterface(params.market).withdrawFrom(
			params.from,
			params.to,
			token_,
			amt_
		);

		uint256 finalBal = CometInterface(params.market).borrowBalanceOf(
			params.from
		);
		amt_ = finalBal - initialBal;

		if (params.to == address(this))
			convertWethToEth(isEth, tokenContract, amt_);

		amt = amt_;
	}

	function _withdraw(BorrowWithdrawParams memory params)
		internal
		returns (uint256 amt)
	{
		uint256 amt_ = params.amt;

		require(
			params.market != address(0) &&
				params.token != address(0) &&
				params.to != address(0),
			"invalid market/token/to address"
		);

		bool isEth = params.token == ethAddr;
		address token_ = isEth ? wethAddr : params.token;

		TokenInterface tokenContract = TokenInterface(token_);
		params.from = params.from == address(0) ? address(this) : params.from;

		uint256 initialBal = _getAccountSupplyBalanceOfAsset(
			params.from,
			params.market,
			token_
		);

		if (token_ == getBaseToken(params.market)) {
			//if there are supplies, ensure withdrawn amount is not greater than supplied i.e can't borrow using withdraw.
			if (amt_ == type(uint).max) {
				amt_ = initialBal;
			} else {
				require(
					amt_ <= initialBal,
					"withdraw-amt-greater-than-supplies"
				);
			}

			//if borrow balance > 0, there are no supplies so no withdraw, borrow instead.
			require(
				CometInterface(params.market).borrowBalanceOf(params.from) == 0,
				"withdraw-disabled-for-zero-supplies"
			);
		} else {
			amt_ = amt_ == type(uint).max ? initialBal : amt_;
		}

		CometInterface(params.market).withdrawFrom(
			params.from,
			params.to,
			token_,
			amt_
		);

		uint256 finalBal = _getAccountSupplyBalanceOfAsset(
			params.from,
			params.market,
			token_
		);
		amt_ = initialBal - finalBal;

		if (params.to == address(this))
			convertWethToEth(isEth, tokenContract, amt_);

		amt = amt_;
	}

	function _getAccountSupplyBalanceOfAsset(
		address account,
		address market,
		address asset
	) internal returns (uint256 balance) {
		if (asset == getBaseToken(market)) {
			//balance in base
			balance = CometInterface(market).balanceOf(account);
		} else {
			//balance in asset denomination
			balance = uint256(
				CometInterface(market).userCollateral(account, asset).balance
			);
		}
	}

	function _calculateFromAmount(
		address market,
		address token,
		address src,
		uint256 amt,
		bool isEth,
		Action action
	) internal view returns (uint256) {
		if (amt == type(uint).max) {
			uint256 allowance_ = TokenInterface(token).allowance(src, market);
			uint256 bal_;

			if (action == Action.REPAY) {
				bal_ = CometInterface(market).borrowBalanceOf(src);
			} else if (action == Action.DEPOSIT) {
				if (isEth) bal_ = src.balance;
				else bal_ = TokenInterface(token).balanceOf(src);
			}

			amt = bal_ < allowance_ ? bal_ : allowance_;
		}

		return amt;
	}

	function _buyCollateral(
		BuyCollateralData memory params
	) internal returns (string memory eventName_, bytes memory eventParam_) {
		uint256 sellAmt_ = params.baseSellAmt;
		require(
			params.market != address(0) && params.buyAsset != address(0),
			"invalid market/token address"
		);

		bool isEth = params.sellToken == ethAddr;
		params.sellToken = isEth ? wethAddr : params.sellToken;

		require(
			params.sellToken == getBaseToken(params.market),
			"invalid-sell-token"
		);

		if (sellAmt_ == type(uint).max) {
			sellAmt_ = isEth
				? address(this).balance
				: TokenInterface(params.sellToken).balanceOf(address(this));
		}
		convertEthToWeth(isEth, TokenInterface(params.sellToken), sellAmt_);

		isEth = params.buyAsset == ethAddr;
		params.buyAsset = isEth ? wethAddr : params.buyAsset;

		uint256 slippageAmt_ = convert18ToDec(
			TokenInterface(params.buyAsset).decimals(),

			params.unitAmt * convertTo18(
					TokenInterface(params.sellToken).decimals(),
					sellAmt_
				)
		);

		uint256 initialCollBal_ = TokenInterface(params.buyAsset).balanceOf(
			address(this)
		);

		approve(TokenInterface(params.sellToken), params.market, sellAmt_);
		CometInterface(params.market).buyCollateral(
			params.buyAsset,
			slippageAmt_,
			sellAmt_,
			address(this)
		);

		uint256 finalCollBal_ = TokenInterface(params.buyAsset).balanceOf(
			address(this)
		);

		uint256 buyAmt_ = finalCollBal_ - initialCollBal_;
		require(slippageAmt_ <= buyAmt_, "too-much-slippage");

		convertWethToEth(isEth, TokenInterface(params.buyAsset), buyAmt_);

		eventName_ = "LogBuyCollateral(address,address,uint256,uint256,uint256)";
		eventParam_ = abi.encode(
			params.market,
			params.buyAsset,
			sellAmt_,
			params.unitAmt,
			buyAmt_
		);
	}
}
