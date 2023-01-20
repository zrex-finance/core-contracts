// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../connectors/common/interfaces.sol";

import { Helpers } from "./helpers.sol";
import { SwapData, OneInchData } from "./interface.sol";

contract Exchanges is Helpers {
    function exchange(
        address buyAddr,
		address sellAddr,
		uint256 sellAmt,
		uint256 unitAmt,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt) {
        if (_route == 1) {
            _buyAmt = routeUni(buyAddr, sellAddr, sellAmt, unitAmt, callData);
        } else if (_route == 2) {
            _buyAmt = routeOneInch(buyAddr, sellAddr, sellAmt, unitAmt, callData);
        } else {
            revert("route-does-not-exist");
        }
    }

    function routeUni(
        address buyAddr,
        address sellAddr,
        uint sellAmt,
        uint unitAmt,
        bytes calldata callData
    ) internal returns (uint256) {
        SwapData memory swapData = SwapData({
			buyToken: TokenInterface(buyAddr),
			sellToken: TokenInterface(sellAddr),
			unitAmt: unitAmt,
			callData: callData,
			_sellAmt: sellAmt,
			_buyAmt: 0
		});

        return uniSwap(swapData);
    }

    function routeOneInch(
        address buyAddr,
        address sellAddr,
        uint sellAmt,
        uint unitAmt,
        bytes calldata callData
    ) internal returns (uint256) {
        OneInchData memory oneInchData = OneInchData({
            buyToken: TokenInterface(buyAddr),
            sellToken: TokenInterface(sellAddr),
            unitAmt: unitAmt,
            callData: callData,
            _sellAmt: sellAmt,
            _buyAmt: 0
        });

        return oneInchSwap(oneInchData);
    }
}