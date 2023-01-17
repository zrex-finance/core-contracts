// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFlashLoan {
    function flashLoan(
        address[] memory tokens_,
        uint256[] memory amts_,
        uint256 route,
        bytes calldata data_,
        bytes calldata _customData
    ) external;
}

contract FlashReceiver {
    using SafeERC20 for IERC20;
    IFlashLoan internal immutable flashloan;
    
    function flashBorrow(
        address[] calldata tokens_,
        uint256[] calldata amts_,
        uint256 route,
        bytes calldata data_,
        bytes calldata _customData
    ) public {
        flashloan.flashLoan(tokens_, amts_, route, data_, _customData);
    }

    // Function which
    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        bytes calldata /* params */
    ) external returns (bool) {
        // Do something
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(
                address(flashloan),
                amounts[i] + premiums[i]
            );
        }
        return true;
    }

    constructor(address flashloan_) {
        flashloan = IFlashLoan(flashloan_);
    }
}