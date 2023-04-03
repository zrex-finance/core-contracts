// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IFlashAggregator {
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external returns (bool);

    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external returns (bytes32);

    function receiveFlashLoan(address[] memory, uint256[] memory, uint256[] memory _fees, bytes memory _data) external;

    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint16 _route,
        bytes calldata _data,
        bytes calldata
    ) external;

    function getRoutes() external pure returns (uint16[] memory routes);

    function calculateFeeBPS(uint256 _route) external view returns (uint256 BPS);
}
