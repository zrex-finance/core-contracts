// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Aave v2.
 * @dev Lending & Borrowing.
 */

import { TokenInterface } from "../../../common/base.sol";
import { Stores } from "../../../common/stores.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";
import { AaveInterface } from "./interface.sol";

abstract contract AaveResolver is Events, Helpers {
	function deposit(
		address token,
		uint256 amt
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		if (isEth) {
			amt = amt == uint256(-1) ? address(this).balance : amt;
			convertEthToWeth(isEth, tokenContract, amt);
		} else {
			amt = amt == uint256(-1)
				? tokenContract.balanceOf(address(this))
				: amt;
		}

		approve(tokenContract, address(aave), amt);

		aave.deposit(_token, amt, address(this), referralCode);

		if (!getIsColl(_token)) {
			aave.setUserUseReserveAsCollateral(_token, true);
		}

		_eventName = "LogDeposit(address,uint256)";
		_eventParam = abi.encode(token, amt);
	}

	function withdraw(
		address token,
		uint256 amt
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		uint256 initialBal = tokenContract.balanceOf(address(this));
		aave.withdraw(_token, amt, address(this));
		uint256 finalBal = tokenContract.balanceOf(address(this));

		amt = finalBal - initialBal;

		convertWethToEth(isEth, tokenContract, amt);

		_eventName = "LogWithdraw(address,uint256)";
		_eventParam = abi.encode(token, amt);
	}

	function borrow(
		address token,
		uint256 amt,
		uint256 rateMode
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{

		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		aave.borrow(_token, amt, rateMode, referralCode, address(this));
		convertWethToEth(isEth, TokenInterface(_token), amt);

		_eventName = "LogBorrow(address,uint256,uint256)";
		_eventParam = abi.encode(token, amt, rateMode);
	}

	function payback(
		address token,
		uint256 amt,
		uint256 rateMode
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		if (amt == uint256(-1)) {
			uint256 _amtDSA = isEth
				? address(this).balance
				: tokenContract.balanceOf(address(this));
			uint256 _amtDebt = getPaybackBalance(_token, rateMode);
			amt = _amtDSA <= _amtDebt ? _amtDSA : _amtDebt;
		}

		if (isEth) convertEthToWeth(isEth, tokenContract, amt);

		approve(tokenContract, address(aave), amt);

		aave.repay(_token, amt, rateMode, address(this));

		_eventName = "LogPayback(address,uint256,uint256)";
		_eventParam = abi.encode(token, amt, rateMode);
	}

	function paybackOnBehalfOf(
		address token,
		uint256 amt,
		uint256 rateMode,
		address onBehalfOf
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		if (amt == uint256(-1)) {
			uint256 _amtDSA = isEth
				? address(this).balance
				: tokenContract.balanceOf(address(this));
			uint256 _amtDebt = getOnBehalfOfPaybackBalance(
				_token,
				rateMode,
				onBehalfOf
			);
			amt = _amtDSA <= _amtDebt ? _amtDSA : _amtDebt;
		}

		if (isEth) convertEthToWeth(isEth, tokenContract, amt);

		approve(tokenContract, address(aave), amt);

		aave.repay(_token, amt, rateMode, onBehalfOf);

		_eventName = "LogPaybackOnBehalfOf(address,uint256,uint256,address)";
		_eventParam = abi.encode(
			token,
			_amt,
			rateMode,
			onBehalfOf
		);
	}

	function enableCollateral(address[] calldata tokens)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		uint256 _length = tokens.length;
		require(_length > 0, "0-tokens-not-allowed");

		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

		for (uint256 i = 0; i < _length; i++) {
			bool isEth = tokens[i] == ethAddr;
			address _token = isEth ? wethAddr : tokens[i];

			if (getCollateralBalance(_token) > 0 && !getIsColl(_token)) {
				aave.setUserUseReserveAsCollateral(_token, true);
			}
		}

		_eventName = "LogEnableCollateral(address[])";
		_eventParam = abi.encode(tokens);
	}

	function swapBorrowRateMode(address token, uint256 rateMode)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		if (getPaybackBalance(_token, rateMode) > 0) {
			aave.swapBorrowRateMode(_token, rateMode);
		}

		_eventName = "LogSwapRateMode(address,uint256)";
		_eventParam = abi.encode(token, rateMode);
	}
}

contract ConnectV2AaveV2 is AaveResolver {
	string public constant name = "AaveV2-v1.2";
}
