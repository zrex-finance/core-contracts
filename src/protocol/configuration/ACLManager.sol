// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { AccessControl } from "../../dependencies/openzeppelin/contracts/AccessControl.sol";
import { IAddressesProvider } from "../../interfaces/IAddressesProvider.sol";
import { Errors } from "../libraries/helpers/Errors.sol";

/**
 * @title ACLManager
 * @author FlashFlow
 * @notice Access Control List Manager. Main registry of system roles and permissions.
 */
contract ACLManager is AccessControl {
    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");
    bytes32 public constant CONNECTOR_ADMIN_ROLE = keccak256("CONNECTOR_ADMIN_ROLE");

    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /**
     * @dev Constructor
     * @dev The ACL admin should be initialized at the addressesProvider beforehand
     * @param provider The address of the AddressesProvider
     */
    constructor(IAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        address aclAdmin = provider.getACLAdmin();
        require(aclAdmin != address(0), Errors.ACL_ADMIN_CANNOT_BE_ZERO);
        _setupRole(DEFAULT_ADMIN_ROLE, aclAdmin);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function addConnectorAdmin(address admin) external {
        grantRole(CONNECTOR_ADMIN_ROLE, admin);
    }

    function removeConnectorAdmin(address admin) external {
        revokeRole(CONNECTOR_ADMIN_ROLE, admin);
    }

    function isConnectorAdmin(address admin) external view returns (bool) {
        return hasRole(CONNECTOR_ADMIN_ROLE, admin);
    }

    function addRouterAdmin(address admin) external {
        grantRole(ROUTER_ADMIN_ROLE, admin);
    }

    function removeRouterAdmin(address admin) external {
        revokeRole(ROUTER_ADMIN_ROLE, admin);
    }

    function isRouterAdmin(address admin) external view returns (bool) {
        return hasRole(ROUTER_ADMIN_ROLE, admin);
    }
}
