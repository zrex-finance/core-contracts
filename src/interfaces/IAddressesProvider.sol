// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IAddressesProvider {
    function getAddress(bytes32 id) external view returns (address);

    function setAddress(bytes32 id, address newAddress) external;

    function getRouter() external view returns (address);

    function getConnectors() external view returns (address);

    function getImplementations() external view returns (address);

    function getMapping() external view returns (address);

    function getFlashloanAggregator() external view returns (address);

    function getPoolConfigurator() external view returns (address);

    function getTreasury() external view returns (address);

    function getAccountProxy() external view returns (address);
}
