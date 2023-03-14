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
    bytes32 private constant FLASHLOAN_AGGREGATOR = "FLASHLOAN_AGGREGATOR";

    event AddressSet(bytes32 indexed id, address indexed oldAddress, address indexed newAddress);

    function getAddress(bytes32 id) public view returns (address) {
        return _addresses[id];
    }

    function setAddress(bytes32 id, address newAddress) external onlyOwner {
        address oldAddress = _addresses[id];
        _addresses[id] = newAddress;
        emit AddressSet(id, oldAddress, newAddress);
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

    function getTreasury() external view returns (address) {
        return getAddress(TREASURY);
    }

    function getAccountProxy() external view returns (address) {
        return getAddress(ACCOUNT_PROXY);
    }
}
