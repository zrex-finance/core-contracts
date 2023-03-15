// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFlashAggregator {
    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint16 _route,
        bytes calldata _data,
        bytes calldata
    ) external;
}
