// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AddressesProvider
 * @author FlashFlow
 * @notice Main registry of addresses part of or connected to the protocol
 * @dev Acts as factory of proxies, so with right to change its implementations
 */
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

    /**
     * @param _id The key to obtain the address.
     * @return Returns the contract address.
     */
    function getAddress(bytes32 _id) public view returns (address) {
        return _addresses[_id];
    }

    /**
     * @dev Set contract address for the current id.
     * @param _id Contract name in bytes32.
     * @param _newAddress New contract address.
     */
    function setAddress(bytes32 _id, address _newAddress) external onlyOwner {
        address oldAddress = _addresses[_id];
        _addresses[_id] = _newAddress;
        emit AddressSet(_id, oldAddress, _newAddress);
    }

    /**
     * @notice Returns the address of the Router proxy.
     * @return The Router proxy address
     */
    function getRouter() external view returns (address) {
        return getAddress(ROUTER);
    }

    /**
     * @notice Returns the address of the Connectors proxy.
     * @return The Connectors proxy address
     */
    function getConnectors() external view returns (address) {
        return getAddress(CONNECTORS);
    }

    /**
     * @notice Returns the address of the Implementations proxy.
     * @return The Implementations proxy address
     */
    function getImplementations() external view returns (address) {
        return getAddress(IMPLEMENTATIONS);
    }

    /**
     * @notice Returns the address of the Flashloan aggregator proxy.
     * @return The Flashloan aggregator proxy address
     */
    function getFlashloanAggregator() external view returns (address) {
        return getAddress(FLASHLOAN_AGGREGATOR);
    }

    /**
     * @notice Returns the address of the Treasury proxy.
     * @return The Treasury proxy address
     */
    function getTreasury() external view returns (address) {
        return getAddress(TREASURY);
    }

    /**
     * @notice Returns the address of the Account proxy.
     * @return The Account proxy address
     */
    function getAccountProxy() external view returns (address) {
        return getAddress(ACCOUNT_PROXY);
    }
}
