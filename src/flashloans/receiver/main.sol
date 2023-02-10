// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces.sol";
import { FlashReceiverHelper } from "./helpers.sol";

contract FlashReceiver is FlashReceiverHelper {
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
        transferTokens(address(positionsRouter), tokens, amounts, premiums, false);

        bytes memory encodeParams = encodingParams(params, amounts[0] + premiums[0]);

        (bool success, bytes memory results) = address(positionsRouter).call(encodeParams);

        if (!success) {
            revert(_getRevertMsg(results));
        }

        transferTokens(address(flashloanAggregator), tokens, amounts, premiums, true);

        return true;
    }

    function setRouter(address _positionRouter) public {
        positionsRouter = _positionRouter;
    }

    function transferTokens(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        bool withFee
    ) private {
        for (uint256 i = 0; i < tokens.length; i++) {
                uint256 amt = withFee ? amounts[i] + premiums[i] : amounts[i];
                IERC20(tokens[i]).safeTransfer(recipient, amt);
            }
    }

    function encodingParams(bytes memory params, uint256 amount) internal pure returns (bytes memory encode) {
        (
            bytes4 selector,
            address[] memory _targets,
            bytes[] memory _datas,
            bytes[] memory _customDatas,
            address _origin
        ) = abi.decode(params, (bytes4, address[], bytes[], bytes[], address));

        encode = abi.encodeWithSelector(selector, _targets, _datas, _customDatas, _origin, amount);
    }

    constructor(address flashloanAggregator_) {
        flashloanAggregator = IFlashLoan(flashloanAggregator_);
    }
}