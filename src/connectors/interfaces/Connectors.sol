// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IConnector {
    function connectorId() external view returns (uint _id);

    function name() external view returns (string memory);
}
