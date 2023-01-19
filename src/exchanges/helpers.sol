// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Basic } from "../connectors/common/base.sol";
import { TokenInterface } from "../connectors/common/interfaces.sol";

import { SwapData, OneInchInterace, OneInchData } from "./interface.sol";

abstract contract Helpers is Basic {
	address internal constant V3_SWAP_ROUTER_ADDRESS = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
	address internal constant oneInchAddr = 0x1111111254EEB25477B68fb85Ed929f73A960582;

	function _uniSwap(SwapData memory swapData) internal returns (uint256 buyAmt) {
		uint256 initalBal = getTokenBalance(swapData.buyToken);

		(bool success, ) = V3_SWAP_ROUTER_ADDRESS.call(swapData.callData);
		if (!success) revert("uniswapV3-swap-failed");

		uint256 finalBal = getTokenBalance(swapData.buyToken);

		buyAmt = finalBal - initalBal;
	}


	function uniSwap(SwapData memory swapData) internal returns (uint256 _buyAmt)	{
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

		_buyAmt = _uniSwap(swapData);

		convertWethToEth(isEthBuyToken, swapData.buyToken, _buyAmt);
	}

	function _oneInchSwap(
        OneInchData memory oneInchData,
        uint ethAmt
    ) internal returns (uint buyAmt) {
        TokenInterface buyToken = oneInchData.buyToken;

        uint initalBal = getTokenBalance(buyToken);

        (bool success, ) = oneInchAddr.call{value: ethAmt}(oneInchData.callData);
        if (!success) revert("1Inch-swap-failed");

        uint finalBal = getTokenBalance(buyToken);

        buyAmt = finalBal - initalBal;
    }

	function oneInchSwap(
        OneInchData memory oneInchData
    ) internal returns (uint256 _buyAmt) {
        TokenInterface _sellAddr = oneInchData.sellToken;

        uint ethAmt;
        if (address(_sellAddr) == ethAddr) {
            ethAmt = oneInchData._sellAmt;
        } else {
            approve(TokenInterface(_sellAddr), oneInchAddr, oneInchData._sellAmt);
        }

        _buyAmt = _oneInchSwap(oneInchData, ethAmt);
    }
}
