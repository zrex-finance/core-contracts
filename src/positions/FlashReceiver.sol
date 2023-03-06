// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { Utils } from "../utils/Utils.sol";
import { EthConverter } from "../utils/EthConverter.sol";

import { IImplimentation, IFlashLoan } from "./interfaces/FlashReceiver.sol";

contract FlashReceiver is Initializable, Utils, EthConverter {
    IFlashLoan public flashloanAggregator;

    modifier onlyAggregator() {
        require(msg.sender == address(flashloanAggregator), "Access denied");
        _;
    }

    function __FlashReceiver_init(address _flashloanAggregator) internal onlyInitializing {
		flashloanAggregator = IFlashLoan(_flashloanAggregator);
	}

    function flashloan(
        address _token,
        uint256 _amount,
        uint256 route,
        bytes calldata _data
    ) public {
        address[] memory _tokens = new address[](1);
        _tokens[0] = _token;

        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        flashloanAggregator.flashLoan(_tokens, _amounts, route, _data, bytes(""));
    }

    function executeOperation(
        address[] calldata /* tokens */,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external onlyAggregator returns (bool) {
        require(initiator == address(this), "account will be initiator");
        // convertWethToEth(tokens[0], amounts[0]);

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
            string[] memory _targetNames,
            bytes[] memory _datas,
            bytes[] memory _customDatas
        ) = abi.decode(params, (bytes4, string[], bytes[], bytes[]));

        encode = abi.encodeWithSelector(selector, _targetNames, _datas, _customDatas, amount);
    }
}