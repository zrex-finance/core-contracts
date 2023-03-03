// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISwapRouter {
    function swap(
        address buyAddr,
		address sellAddr,
		uint256 sellAmt,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt);
}