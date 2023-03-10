// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { EthConverter } from "../utils/EthConverter.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

contract UniswapConnector is EthConverter {
    using UniversalERC20 for IERC20;

    string public name = "UniswapAuto";

    address internal constant uniAutoRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    function swap(
        address toToken,
        address fromToken,
        uint256 amount,
        bytes calldata callData
    ) external payable returns (uint256 _buyAmt) {
        _buyAmt = _swap(toToken, fromToken, amount, callData);
        emit LogExchange(msg.sender, toToken, fromToken, amount);
    }

    function _swap(
        address toToken,
        address fromToken,
        uint256 amount,
        bytes calldata callData
    ) internal returns (uint256 buyAmount) {
        IERC20(fromToken).universalApprove(uniAutoRouter, amount);

        uint256 initalBalalance = IERC20(toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = uniAutoRouter.call(callData);

        if (!success) {
            revert(string(results));
        }

        uint256 finalBalalance = IERC20(toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }

    event LogExchange(address indexed account, address buyAddr, address sellAddr, uint256 sellAmt);
}
