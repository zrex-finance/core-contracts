// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFlashReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata _data
    ) external returns (bool);
}
