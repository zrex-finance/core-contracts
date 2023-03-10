// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { SharedStructs } from "../../lib/SharedStructs.sol";

interface IConnectors {
    function isConnectors(string[] calldata _names) external view returns (bool isOk, address[] memory _connectors);

    function isConnector(string calldata _name) external view returns (bool isOk, address _connector);
}

interface IAccount {
    function openPosition(
        SharedStructs.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) external payable;

    function closePosition(
        bytes32 key,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) external payable;

    function initialize(
        address _account,
        address _connectors,
        address _positionRouter,
        address _flashloanAggregator
    ) external;
}
