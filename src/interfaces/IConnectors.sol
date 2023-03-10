// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IConnectors {
    function getConnector(string memory _name) external view returns (address);

    function addConnectors(string[] calldata _names, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _names, address[] calldata _connectors) external;

    function removeConnectors(string[] calldata _names) external;

    function isConnectors(string[] calldata _names) external view returns (bool isOk, address[] memory _connectors);

    function isConnector(string calldata _name) external view returns (bool isOk, address _connector);
}
