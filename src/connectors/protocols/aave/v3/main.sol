// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../../../common/interfaces.sol";
import { Stores } from "../../../common/stores.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";
import { AaveInterface, DTokenInterface } from "./interface.sol";

abstract contract AaveResolver is Events, Helpers {
	
	function deposit(
		address token,
		uint256 amt
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		if (isEth) {
			_amt = _amt == type(uint256).max ? address(this).balance : _amt;
			convertEthToWeth(isEth, tokenContract, _amt);
		} else {
			_amt = _amt == type(uint256).max
				? tokenContract.balanceOf(address(this))
				: _amt;
		}

		approve(tokenContract, address(aave), _amt);

		aave.supply(_token, _amt, address(this), referralCode);

		if (!getIsColl(_token)) {
			aave.setUserUseReserveAsCollateral(_token, true);
		}

		_eventName = "LogDeposit(address,uint256)";
		_eventParam = abi.encode(token, _amt);
	}

	function depositWithoutCollateral(
		address token,
		uint256 amt
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		if (isEth) {
			_amt = _amt == type(uint256).max ? address(this).balance : _amt;
			convertEthToWeth(isEth, tokenContract, _amt);
		} else {
			_amt = _amt == type(uint256).max
				? tokenContract.balanceOf(address(this))
				: _amt;
		}

		approve(tokenContract, address(aave), _amt);

		aave.supply(_token, _amt, address(this), referralCode);

		if (getCollateralBalance(_token) > 0 && getIsColl(_token)) {
			aave.setUserUseReserveAsCollateral(_token, false);
		}

		_eventName = "LogDepositWithoutCollateral(address,uint256)";
		_eventParam = abi.encode(token, _amt);
	}

	function withdraw(
		address token,
		uint256 amt
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());
		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		uint256 initialBal = tokenContract.balanceOf(address(this));
		aave.withdraw(_token, _amt, address(this));
		uint256 finalBal = tokenContract.balanceOf(address(this));

		_amt = finalBal - initialBal;

		convertWethToEth(isEth, tokenContract, _amt);

		_eventName = "LogWithdraw(address,uint256)";
		_eventParam = abi.encode(token, _amt);
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
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		aave.borrow(_token, _amt, rateMode, referralCode, address(this));
		convertWethToEth(isEth, TokenInterface(_token), _amt);

		_eventName = "LogBorrow(address,uint256,uint256)";
		_eventParam = abi.encode(token, _amt, rateMode);
	}

	function borrowOnBehalfOf(
		address token,
		uint256 amt,
		uint256 rateMode,
		address onBehalfOf
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		aave.borrow(_token, _amt, rateMode, referralCode, onBehalfOf);
		convertWethToEth(isEth, TokenInterface(_token), _amt);

		_eventName = "LogBorrowOnBehalfOf(address,uint256,uint256,address)";
		_eventParam = abi.encode(
			token,
			_amt,
			rateMode,
			onBehalfOf
		);
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
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		_amt = _amt == type(uint256).max ? getPaybackBalance(_token, rateMode) : _amt;

		if (isEth) convertEthToWeth(isEth, tokenContract, _amt);

		approve(tokenContract, address(aave), _amt);

		aave.repay(_token, _amt, rateMode, address(this));

		_eventName = "LogPayback(address,uint256,uint256)";
		_eventParam = abi.encode(token, _amt, rateMode);
	}

	function paybackWithATokens(
		address token,
		uint256 amt,
		uint256 rateMode
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		_amt = _amt == type(uint256).max ? getPaybackBalance(_token, rateMode) : _amt;

		if (isEth) convertEthToWeth(isEth, tokenContract, _amt);

		approve(tokenContract, address(aave), _amt);

		aave.repayWithATokens(_token, _amt, rateMode);

		_eventName = "LogPayback(address,uint256,uint256)";
		_eventParam = abi.encode(token, _amt, rateMode);
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
		uint256 _amt = amt;

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		TokenInterface tokenContract = TokenInterface(_token);

		_amt = _amt == type(uint256).max
			? getOnBehalfOfPaybackBalance(_token, rateMode, onBehalfOf)
			: _amt;

		if (isEth) convertEthToWeth(isEth, tokenContract, _amt);

		approve(tokenContract, address(aave), _amt);

		aave.repay(_token, _amt, rateMode, onBehalfOf);

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

		AaveInterface aave = AaveInterface(aaveProvider.getPool());

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
		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		if (getPaybackBalance(_token, rateMode) > 0) {
			aave.swapBorrowRateMode(_token, rateMode);
		}

		_eventName = "LogSwapRateMode(address,uint256)";
		_eventParam = abi.encode(token, rateMode);
	}

	function setUserEMode(uint8 categoryId)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		AaveInterface aave = AaveInterface(aaveProvider.getPool());

		aave.setUserEMode(categoryId);

		_eventName = "LogSetUserEMode(uint8)";
		_eventParam = abi.encode(categoryId);
	}

	function delegateBorrow(
		address token,
		uint256 amount,
		uint256 rateMode,
		address delegateTo
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		require(rateMode == 1 || rateMode == 2, "Invalid debt type");
		uint256 _amt = amount;

		bool isEth = token == ethAddr;
		address _token = isEth ? wethAddr : token;

		address _dToken = getDTokenAddr(_token, rateMode);
		DTokenInterface(_dToken).approveDelegation(delegateTo, _amt);

		_eventName = "LogDelegateBorrow(address,uint256,uint256,address)";
		_eventParam = abi.encode(
			token,
			_amt,
			rateMode,
			delegateTo
		);
	}
}

