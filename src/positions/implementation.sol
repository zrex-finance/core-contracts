// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../lib/UniversalERC20.sol";

import { IPositionRouter, SharedStructs } from "./interfaces.sol";

import "forge-std/Test.sol";

contract Implementation is Test, Initializable {
	 using UniversalERC20 for IERC20;

	 IPositionRouter private positionRouter;

    receive() external payable {}

	function initialize(address _positionRouter) public initializer {
        positionRouter = IPositionRouter(_positionRouter);
    }

    function openPosition(
        SharedStructs.Position memory position,
        bool isShort,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        if (!isShort) {
			IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
		}
        IERC20(position.debt).universalApprove(address(positionRouter), type(uint256).max);

        positionRouter.openPosition{value: msg.value}(position, isShort, _tokens, _amts, route, _data, _customData);
    }

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        positionRouter.closePosition(key, _tokens, _amts, route, _data, _customData);
    }
}