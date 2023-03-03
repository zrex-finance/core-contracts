// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SharedStructs } from "../../lib/SharedStructs.sol";

interface ISwapRouter {
    function swap(
        address buyAddr,
		address sellAddr,
		uint256 sellAmt,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt);
}

interface IPositionRouter {
    function openPosition(
        SharedStructs.Position memory position,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function positions(bytes32 _key) external pure returns (
        address account,
        address debt,
        address collateral,
        uint256 amountIn,
        uint256 sizeDelta,
        uint256 collateralAmount,
        uint256 borrowAmount
    );
    function positionsIndex(address _account) external pure returns (uint256);
    function getKey(address _account, uint256 _index) external pure returns (bytes32);

    function openPositionCallback(
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external;

    function swapRouter() external returns (address);
}