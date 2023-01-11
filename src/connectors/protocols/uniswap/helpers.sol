// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Basic } from "../../common/base.sol";
import { TokenInterface } from "../../common/interfaces.sol";

import { SwapData } from "./interface.sol";

abstract contract Helpers is Basic {
	address internal constant V3_SWAP_ROUTER_ADDRESS = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

	function _swapHelper(SwapData memory swapData) internal returns (uint256 buyAmt) {
		uint256 initalBal = getTokenBalance(swapData.buyToken);

		(bool success, ) = V3_SWAP_ROUTER_ADDRESS.call(swapData.callData);
		if (!success) revert("uniswapV3-swap-failed");

		uint256 finalBal = getTokenBalance(swapData.buyToken);

		buyAmt = finalBal - initalBal;
	}


	function _swap(SwapData memory swapData) internal returns (SwapData memory)	{
		bool isEthSellToken = address(swapData.sellToken) == ethAddr;
		bool isEthBuyToken = address(swapData.buyToken) == ethAddr;

		swapData.sellToken = isEthSellToken
			? TokenInterface(wethAddr)
			: swapData.sellToken;
		swapData.buyToken = isEthBuyToken
			? TokenInterface(wethAddr)
			: swapData.buyToken;

		convertEthToWeth(isEthSellToken, swapData.sellToken, swapData._sellAmt);

		approve(
			TokenInterface(swapData.sellToken),
			V3_SWAP_ROUTER_ADDRESS,
			swapData._sellAmt
		);

		swapData._buyAmt = _swapHelper(swapData);

		convertWethToEth(isEthBuyToken, swapData.buyToken, swapData._buyAmt);

		return swapData;
	}
}
