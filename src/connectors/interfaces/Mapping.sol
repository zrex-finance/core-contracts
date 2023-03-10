// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICToken {
    function isCToken() external view returns (bool);

    function underlying() external view returns (address);
}
