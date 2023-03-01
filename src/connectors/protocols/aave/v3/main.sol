// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../lib/UniversalERC20.sol";

import { Helpers } from "./helpers.sol";
import { IAave, IDToken } from "./interface.sol";

abstract contract AaveResolver is Helpers {
	using UniversalERC20 for IERC20;
	
	function deposit(address token,uint256 amount) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		IERC20 tokenC = IERC20(token);

		amount = amount == type(uint256).max
			? tokenC.balanceOf(address(this))
			: amount;

		tokenC.universalApprove(address(aave), amount);

		aave.supply(token, amount, address(this), referralCode);

		if (!getIsColl(token)) {
			aave.setUserUseReserveAsCollateral(token, true);
		}
	}

	function depositWithoutCollateral(address token,uint256 amount) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		IERC20 tokenC = IERC20(token);

		amount = amount == type(uint256).max
			? tokenC.balanceOf(address(this))
			: amount;

		tokenC.universalApprove(address(aave), amount);

		aave.supply(token, amount, address(this), referralCode);

		if (getCollateralBalance(token) > 0 && getIsColl(token)) {
			aave.setUserUseReserveAsCollateral(token, false);
		}
	}

	function withdraw(address token,uint256 amount) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		IERC20 tokenC = IERC20(token);

		uint256 initialBalance = tokenC.balanceOf(address(this));
		aave.withdraw(token, amount, address(this));
		uint256 finalBalance = tokenC.balanceOf(address(this));

		amount = finalBalance - initialBalance;
	}

	function borrow(address token,uint256 amount,uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		aave.borrow(token, amount, rateMode, referralCode, address(this));
	}

	function borrowOnBehalfOf(
		address token,
		uint256 amount,
		uint256 rateMode,
		address onBehalfOf
	) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		aave.borrow(token, amount, rateMode, referralCode, onBehalfOf);
	}

	function payback(address token,uint256 amount,uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		IERC20 tokenC = IERC20(token);

		amount = amount == type(uint256).max 
			? getPaybackBalance(token, rateMode) 
			: amount;

		tokenC.universalApprove(address(aave), amount);
		aave.repay(token, amount, rateMode, address(this));
	}

	function paybackWithATokens(address token,uint256 amount,uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		IERC20 tokenC = IERC20(token);

		amount = amount == type(uint256).max 
			? getPaybackBalance(token, rateMode) 
			: amount;

		tokenC.universalApprove(address(aave), amount);
		aave.repayWithATokens(token, amount, rateMode);
	}

	function paybackOnBehalfOf(
		address token,
		uint256 amount,
		uint256 rateMode,
		address onBehalfOf
	) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		IERC20 tokenC = IERC20(token);

		amount = amount == type(uint256).max
			? getOnBehalfOfPaybackBalance(token, rateMode, onBehalfOf)
			: amount;

		tokenC.universalApprove(address(aave), amount);
		aave.repay(token, amount, rateMode, onBehalfOf);
	}

	function enableCollateral(address[] calldata tokens) external payable {
		uint256 _length = tokens.length;
		require(_length > 0, "0-tokens-not-allowed");

		IAave aave = IAave(aaveProvider.getPool());

		for (uint256 i = 0; i < _length; i++) {
			address token = tokens[i];

			if (getCollateralBalance(token) > 0 && !getIsColl(token)) {
				aave.setUserUseReserveAsCollateral(token, true);
			}
		}
	}

	function swapBorrowRateMode(address token, uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getPool());

		if (getPaybackBalance(token, rateMode) > 0) {
			aave.swapBorrowRateMode(token, rateMode);
		}
	}

	function setUserEMode(uint8 categoryId) external payable {
		IAave aave = IAave(aaveProvider.getPool());
		aave.setUserEMode(categoryId);
	}

	function delegateBorrow(
		address token,
		uint256 amount,
		uint256 rateMode,
		address delegateTo
	) external payable {
		require(rateMode == 1 || rateMode == 2, "Invalid debt type");

		address _dToken = getDTokenAddr(token, rateMode);
		IDToken(_dToken).approveDelegation(delegateTo, amount);
	}
}

