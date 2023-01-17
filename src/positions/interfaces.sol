// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExecutor {
    function execute(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin
    ) external payable;
}
