// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces.sol";
import { Helper } from "./helpers.sol";

contract FlashReceiver is Helper {
    using SafeERC20 for IERC20;
    IFlashLoan internal immutable flashloanAggregator;
    address internal immutable positionsRouter;
    
    function flash(
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) public {
        flashloanAggregator.flashLoan(_tokens, _amts, route, _data, _customData);
    }

    // Function which
    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        bytes calldata params
    ) external returns (bool) {
        // Do something
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(
                address(flashloanAggregator),
                amounts[i] + premiums[i]
            );
        }

        (bool success, bytes memory results) = address(positionsRouter).call(abi.encodePacked(params, amounts[0] + premiums[0]));

        if (!success) {
            revert(_getRevertMsg(results));
        }

        return true;
    }

    constructor(address flashloanAggregator_, address positionsRouter_) {
        flashloanAggregator = IFlashLoan(flashloanAggregator_);
        positionsRouter = positionsRouter_;
    }
}