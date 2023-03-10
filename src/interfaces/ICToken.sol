// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ICToken {
    function isCToken() external view returns (bool);

    function underlying() external view returns (address);
}
