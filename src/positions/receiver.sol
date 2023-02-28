// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IImplimentation, IFlashLoan } from "./interfaces.sol";

import "forge-std/Test.sol";

contract FlashReceiver is Ownable, Test {
    using SafeERC20 for IERC20;

    IFlashLoan public constant flashloanAggregator = IFlashLoan(0xA4AD4f68d0b91CFD19687c881e50f3A00242828c);
    address public constant positionRouter = 0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF;

    modifier onlyAggregator() {
        require(msg.sender == address(flashloanAggregator), "Access denied");
        _;
    }

    function flashloan(
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        address sender,
        bytes calldata _data,
        bytes calldata _customData
    ) public {
        require(sender == msg.sender, "not sender");
        flashloanAggregator.flashLoan(_tokens, _amts, route,sender,_data, _customData);
    }

    // Function which
    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        address origin,
        bytes calldata params
    ) external onlyAggregator returns (bool) {

        uint256 amt = amounts[0] + premiums[0];

        IERC20(tokens[0]).safeTransfer(origin, amt);

        console.log("origin a", IERC20(tokens[0]).balanceOf(origin));
        
        {
            bytes memory encodeParams = encodingParams(params, amt);

            (bool success, bytes memory results) = origin.call(encodeParams);

            if (!success) {
                revert(_getRevertMsg(results));
            }
        }

        IERC20(tokens[0]).safeTransfer(address(flashloanAggregator), amt);

        return true;
    }

    function encodingParams(bytes memory params, uint256 amount) internal view returns (bytes memory encode) {
        (
            bytes4 selector,
            bytes[] memory _datas,
            bytes[] memory _customDatas
        ) = abi.decode(params, (bytes4, bytes[], bytes[]));

        address[] memory targets = new address[](1);
        targets[0] = positionRouter;

		bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeWithSelector(selector,_datas,_customDatas,amount);

        encode = abi.encodeWithSelector(
            IImplimentation.execute.selector, targets, datas, msg.sender
        );
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) {
            return "Transaction reverted silently";
        }

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}