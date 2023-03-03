// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Utils } from "../utils/Utils.sol";

import { IImplimentation, IFlashLoan } from "./interfaces/FlashReceiver.sol";

contract FlashReceiver is Ownable, Utils {
    using SafeERC20 for IERC20;

    IFlashLoan public flashloanAggregator;

    modifier onlyAggregator() {
        require(msg.sender == address(flashloanAggregator), "Access denied");
        _;
    }

    constructor(address flashloanAggregator_) {
        flashloanAggregator = IFlashLoan(flashloanAggregator_);
    }

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
        address[] calldata /* tokens */,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        bytes calldata params
    ) external onlyAggregator returns (bool) {
        bytes memory encodeParams = encodingParams(params, amounts[0] + premiums[0]);
        (bool success, bytes memory results) = address(this).call(encodeParams);
        if (!success) {
            revert(getRevertMsg(results));
        }

        return true;
    }


    function encodingParams(bytes memory params, uint256 amount) internal pure returns (bytes memory encode) {
        (
            bytes4 selector,
            bytes[] memory _datas,
            bytes[] memory _customDatas
        ) = abi.decode(params, (bytes4, bytes[], bytes[]));

        encode = abi.encodeWithSelector(selector, _datas, _customDatas, amount);
    }
}