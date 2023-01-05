// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IEulerDistributor {
    function claim(address account, address token, uint claimable, bytes32[] calldata proof, address stake) external;
}
