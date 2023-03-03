// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Utils } from "../utils/Utils.sol";
import { EthConverter } from "../utils/EthConverter.sol";

import { UniversalERC20 } from "../lib/UniversalERC20.sol";

contract SwapRouter is Utils, EthConverter {
    using UniversalERC20 for IERC20;

    address internal constant uniAutoRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
	address internal constant oneInchV5 = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    function swap(
        address toToken,
		address fromToken,
		uint256 amount,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt) {
        if (_route == 1) {
            _buyAmt = uniSwap(toToken, fromToken, amount, callData);
        } else if (_route == 2) {
            _buyAmt = oneInchSwap(toToken, fromToken, amount, callData);
        } else {
            revert("route does not exist");
        }
        emit LogExchange(msg.sender, _route, toToken, fromToken, amount);
    }

	function uniSwap(
        address toToken,
		address fromToken,
		uint256 amount,
		bytes calldata callData
    ) internal returns (uint256 buyAmount) {
        buyAmount = _swap(toToken,fromToken,amount,uniAutoRouter,callData);
	}

	function oneInchSwap(
        address toToken,
		address fromToken,
		uint256 amount,
		bytes calldata callData
    ) internal returns (uint buyAmount) {
        buyAmount = _swap(toToken,fromToken,amount,oneInchV5,callData);
        convertEthToWeth(toToken, buyAmount);
    }

    function _swap(
        address toToken,
		address fromToken,
		uint256 amount,
        address swapContract,
		bytes calldata callData
    ) internal returns (uint256 buyAmount) {
        IERC20(fromToken).universalApprove(swapContract, amount);

        uint256 value = IERC20(fromToken).isETH() ? amount : 0;

        uint256 initalBalalance = IERC20(toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = swapContract.call{value: value}(callData);
        
		if (!success) {
            revert(getRevertMsg(results));
        }

        uint256 finalBalalance = IERC20(toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }

    event LogExchange(
        address indexed account,
        uint256 indexed route,
        address buyAddr,
		address sellAddr,
		uint256 sellAmt
    );
}