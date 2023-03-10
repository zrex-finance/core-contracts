// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DataTypes } from "../libraries/types/DataTypes.sol";

contract RouterStorage {
    // Fee of the protocol, expressed in bps
    uint256 public fee;

    // Count of user position
    mapping(address => uint256) public positionsIndex;

    // Map of key (user address and position index) to position (userAddress => userAccount)
    mapping(bytes32 => DataTypes.Position) public positions;

    // Map of users address and their account (userAddress => userAccount)
    mapping(address => address) public accounts;
}
