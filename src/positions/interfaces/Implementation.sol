// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SharedStructs } from "../../lib/SharedStructs.sol";

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

    function decodeAndExecute(bytes memory _data) external returns (bytes memory response);
    function connectors() external returns (address);
    function treasury() external returns (address);
    function positions(bytes32 key) external returns (SharedStructs.Position memory);
    function updatePosition(SharedStructs.Position memory position) external;
    function getFeeAmount(uint256 _amount) external view returns (uint256 feeAmount);
}

interface IConnectors {
    function isConnector(string calldata _name) external view returns (bool isOk, address _connector);
}