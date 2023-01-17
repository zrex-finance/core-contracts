// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


contract PositionsRouter {
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 sizeDelta;
    }

    mapping (bytes32 => Position) public positions;
    mapping (address => uint256) public positionsIndex;

    function openPosition(Position memory position) external payable {
        require(position.account == msg.sender, "Only owner");

        address account = position.account;
        uint256 index = positionsIndex[account] += 1;
        positionsIndex[account] = index;

        bytes32 key = getKey(position.account, index);

        positions[key] = position;
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }
}