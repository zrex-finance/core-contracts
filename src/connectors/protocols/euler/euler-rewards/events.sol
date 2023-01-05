// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Events {
    event LogClaimed(
        address user,
        address token,
        uint256 amt,
        uint256 setId
    );
}
