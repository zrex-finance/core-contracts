// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces.sol";
import { Helper } from "./helpers.sol";

import "hardhat/console.sol";

contract FlashReceiver is Helper {
    using SafeERC20 for IERC20;
    IFlashLoan internal immutable flashloanAggregator;
    address internal positionsRouter;
    
    function flashloan(
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) public {
        console.log("FlashReceiver flashloan close");
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
        console.log("executeOperation");
        transferTokens(address(positionsRouter), tokens, amounts, premiums);

        uint256 amoutWing = amounts[0] + premiums[0];

        bytes memory encodeParams;

        {
            (
                bytes4 selector,
                address[] memory _targets,
                bytes[] memory _datas,
                bytes[] memory _customDatas,
                address _origin
            ) = abi.decode(params, (bytes4, address[], bytes[], bytes[], address));

            encodeParams = abi.encodeWithSelector(selector, _targets, _datas, _customDatas, _origin, amoutWing);
        }

        console.log("encode call");
        (bool success, bytes memory results) = address(positionsRouter).call(encodeParams);
        console.log("encode call success", success);

        if (!success) {
            revert(_getRevertMsg(results));
        }

        transferTokens(address(flashloanAggregator), tokens, amounts, premiums);

        return true;
    }

    function setRouter(address _positionRouter) public {
        positionsRouter = _positionRouter;
    }

    function transferTokens(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums
    ) private {
        for (uint256 i = 0; i < tokens.length; i++) {
                IERC20(tokens[i]).safeTransfer(recipient,amounts[i] + premiums[i]);
            }
    }

    constructor(address flashloanAggregator_) {
        flashloanAggregator = IFlashLoan(flashloanAggregator_);
    }
}