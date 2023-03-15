// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DataTypes } from "../libraries/types/DataTypes.sol";

/**
 * @title RouterStorage
 * @author FlashFlow
 * @notice Contract used as storage of the Router contract.
 * @dev It defines the storage layout of the Router contract.
 */
contract RouterStorage {
    // Fee of the protocol, expressed in bps
    uint256 public fee;

    // Count of user position
    mapping(address => uint256) public positionsIndex;

    // Map of key (user address and position index) to position (key => postion)
    mapping(bytes32 => DataTypes.Position) public positions;

    // Map of users address and their account (userAddress => userAccount)
    mapping(address => address) public accounts;
}
