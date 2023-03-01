// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../lib/UniversalERC20.sol";

import { AaveHelpers } from "./helpers.sol";
import { IAave } from "./interface.sol";

abstract contract AaveResolver is AaveHelpers {
	using UniversalERC20 for IERC20;

	function deposit(address token,uint256 amount) external payable {
		IAave aave = IAave(aaveProvider.getLendingPool());

		IERC20 tokenC = IERC20(token);

		amount = amount == type(uint).max
			? tokenC.balanceOf(address(this))
			: amount;

		tokenC.universalApprove(address(aave), amount);

		aave.deposit(token, amount, address(this), referralCode);

		if (!getIsColl(token)) {
			aave.setUserUseReserveAsCollateral(token, true);
		}
	}

	function withdraw(address token,uint256 amount) external payable {
		IAave aave = IAave(aaveProvider.getLendingPool());
		IERC20 tokenC = IERC20(token);

		uint256 initialBal = tokenC.balanceOf(address(this));
		aave.withdraw(token, amount, address(this));
		uint256 finalBal = tokenC.balanceOf(address(this));

		amount = finalBal - initialBal;
	}

	function borrow(address token,uint256 amount,uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getLendingPool());

		aave.borrow(token, amount, rateMode, referralCode, address(this));
	}

	function payback(address token,uint256 amount,uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getLendingPool());

		IERC20 tokenC = IERC20(token);

		if (amount == type(uint).max) {
			uint256 _amount = tokenC.balanceOf(address(this));
			uint256 _amountDebt = getPaybackBalance(token, rateMode);
			amount = _amount <= _amountDebt ? _amount : _amountDebt;
		}

		tokenC.universalApprove(address(aave), amount);

		aave.repay(token, amount, rateMode, address(this));
	}

	function paybackOnBehalfOf(
		address token,
		uint256 amount,
		uint256 rateMode,
		address onBehalfOf
	) external payable {
		IAave aave = IAave(aaveProvider.getLendingPool());

		IERC20 tokenC = IERC20(token);

		if (amount == type(uint).max) {
			uint256 _amount = tokenC.balanceOf(address(this));
			uint256 _amountDebt = getOnBehalfOfPaybackBalance(
				token,
				rateMode,
				onBehalfOf
			);
			amount = _amount <= _amountDebt ? _amount : _amountDebt;
		}

		tokenC.universalApprove(address(aave), amount);

		aave.repay(token, amount, rateMode, onBehalfOf);
	}

	function enableCollateral(address[] calldata tokens) external payable {
		uint256 _length = tokens.length;
		require(_length > 0, "tokens not allowed");

		IAave aave = IAave(aaveProvider.getLendingPool()); 

		for (uint256 i = 0; i < _length; i++) {
			address _token = tokens[i];

			if (getCollateralBalance(_token) > 0 && !getIsColl(_token)) {
				aave.setUserUseReserveAsCollateral(_token, true);
			}
		}
	}

	function swapBorrowRateMode(address token, uint256 rateMode) external payable {
		IAave aave = IAave(aaveProvider.getLendingPool());

		if (getPaybackBalance(token, rateMode) > 0) {
			aave.swapBorrowRateMode(token, rateMode);
		}
	}
}

contract AaveV2Connector is AaveResolver {
	string public constant name = "AaveV2";
}