// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAaveFlashloan {
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external returns (bool);
}
