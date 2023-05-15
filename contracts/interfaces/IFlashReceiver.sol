// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFlashReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        string memory targetName,
        bytes calldata params
    ) external;
}
