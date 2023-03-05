// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SharedStructs } from "../../lib/SharedStructs.sol";

interface IAccount {
    function openPosition(
        SharedStructs.Position memory position,
        bool isShort,
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

    function initialize(address _account, address _positionRouter) external;
}