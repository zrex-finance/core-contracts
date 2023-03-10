// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface AccountImplementations {
    function getImplementation(bytes4 _sig) external view returns (address);
}
