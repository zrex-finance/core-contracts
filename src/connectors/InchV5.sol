// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Utils } from "../utils/Utils.sol";
import { EthConverter } from "../utils/EthConverter.sol";

import { UniversalERC20 } from "../lib/UniversalERC20.sol";

contract InchV5Connector is Utils, EthConverter {
    using UniversalERC20 for IERC20;

    string public name = "1Inch-v5";

    address internal constant oneInchV5 = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    
    function swap(
        address toToken,
		address fromToken,
		uint256 amount,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt) {
        _buyAmt = _swap(toToken, fromToken, amount, callData);
        convertEthToWeth(toToken, _buyAmt);
        emit LogExchange(msg.sender, toToken, fromToken, amount);
    }

    function _swap(
        address toToken,
		address fromToken,
		uint256 amount,
		bytes calldata callData
    ) internal returns (uint256 buyAmount) {
        IERC20(fromToken).universalApprove(oneInchV5, amount);

        uint256 value = IERC20(fromToken).isETH() ? amount : 0;

        uint256 initalBalalance = IERC20(toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = oneInchV5.call{value: value}(callData);
        
		if (!success) {
            revert(getRevertMsg(results));
        }

        uint256 finalBalalance = IERC20(toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }

    event LogExchange(
        address indexed account,
        address buyAddr,
		address sellAddr,
		uint256 sellAmt
    );
}

