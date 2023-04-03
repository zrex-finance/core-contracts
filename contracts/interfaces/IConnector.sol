// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IConnector {
    function name() external view returns (string memory);
}
