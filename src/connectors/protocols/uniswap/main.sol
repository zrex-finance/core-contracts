// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Stores } from "../../common/stores.sol";
import { TokenInterface } from "../../common/interfaces.sol";
import { SwapData } from "./interface.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

abstract contract AutoRouter is Helpers, Events {

	function sell(
		address buyAddr,
		address sellAddr,
		uint256 sellAmt,
		uint256 unitAmt,
		bytes calldata callData
	)
		external
		payable
		returns (string memory _eventName, bytes memory _eventParam)
	{
		SwapData memory swapData = SwapData({
			buyToken: TokenInterface(buyAddr),
			sellToken: TokenInterface(sellAddr),
			unitAmt: unitAmt,
			callData: callData,
			_sellAmt: sellAmt,
			_buyAmt: 0
		});

		swapData = _swap(swapData);

		_eventName = "LogSwap(address,address,uint256,uint256,uint256)";
		_eventParam = abi.encode(
			buyAddr,
			sellAddr,
			swapData._buyAmt,
			swapData._sellAmt,
			0
		);
	}
}

contract ConnectV2UniswapV3AutoRouter is AutoRouter {
	string public name = "UniswapV3-Auto-Router-v1";
}
