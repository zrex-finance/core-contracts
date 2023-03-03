// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { IPositionRouter, SharedStructs, ISwapRouter } from "./interfaces/Implementation.sol";

contract Implementation is Initializable {
	 using UniversalERC20 for IERC20;

	 ISwapRouter private swapRouter;
	 IPositionRouter private positionRouter;

    receive() external payable {}

	function initialize(address _positionRouter) public initializer {
        positionRouter = IPositionRouter(_positionRouter);
		swapRouter = ISwapRouter(positionRouter.swapRouter());
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
        if (isShort) {
			uint256 value = swap(_customData);
            position.amountIn = value;
		} else {
			IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
		}
        IERC20(position.debt).universalApprove(address(positionRouter), position.amountIn);

        positionRouter.openPosition{value: msg.value}(
			position, _tokens, _amts, route, _data, _customData
		);
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

	function swap(bytes calldata _customData) internal returns(uint256 value) {
		(
            address buyAddr,
            address sellAddr,
            uint256 sellAmt,
            uint256 _route,
            bytes memory callData
        ) = abi.decode(_customData, (address, address, uint256, uint256, bytes));

		IERC20(sellAddr).universalTransferFrom(msg.sender, address(this), sellAmt);

        (bool success, bytes memory response) = address(swapRouter).delegatecall(
            abi.encodeWithSelector(swapRouter.swap.selector, buyAddr, sellAddr, sellAmt, _route, callData)
        );
		require(success);

		value = abi.decode(response, (uint256));
	}
}