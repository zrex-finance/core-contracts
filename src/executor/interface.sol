// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ConnectorsInterface {
  function isConnectors(string[] calldata connectorNames) external view returns (bool, address[] memory);
}