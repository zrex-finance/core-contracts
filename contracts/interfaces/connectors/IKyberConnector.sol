// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IKyberConnector {
    function name() external returns (string memory);

    function swap(address _toToken, address _fromToken, uint256 _amount) external payable returns (uint256 buyAmount);
}
