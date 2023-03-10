// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract AddressesProvider is Ownable {
    // Map of registered addresses (identifier => registeredAddress)
    mapping(bytes32 => address) private _addresses;

    // Main identifiers
    bytes32 private constant ROUTER = "ROUTER";
    bytes32 private constant TREASURY = "TREASURY";
    bytes32 private constant CONNECTORS = "CONNECTORS";
    bytes32 private constant ACCOUNT_PROXY = "ACCOUNT_PROXY";
    bytes32 private constant IMPLEMENTATIONS = "IMPLEMENTATIONS";
    bytes32 private constant ROUTER_CONFIGURATOR = "ROUTER_CONFIGURATOR";
    bytes32 private constant FLASHLOAN_AGGREGATOR = "FLASHLOAN_AGGREGATOR";

    function getAddress(bytes32 id) public view returns (address) {
        return _addresses[id];
    }

    function setAddress(bytes32 id, address newAddress) external onlyOwner {
        _addresses[id] = newAddress;
    }

    function getRouter() external view returns (address) {
        return getAddress(ROUTER);
    }

    function getConnectors() external view returns (address) {
        return getAddress(CONNECTORS);
    }

    function getImplementations() external view returns (address) {
        return getAddress(IMPLEMENTATIONS);
    }

    function getFlashloanAggregator() external view returns (address) {
        return getAddress(FLASHLOAN_AGGREGATOR);
    }

    function getPoolConfigurator() external view returns (address) {
        return getAddress(ROUTER_CONFIGURATOR);
    }

    function getTreasury() external view returns (address) {
        return getAddress(TREASURY);
    }

    function getAccountProxy() external view returns (address) {
        return getAddress(ACCOUNT_PROXY);
    }
}
