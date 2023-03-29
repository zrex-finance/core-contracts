// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IACLManager {
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function addConnectorAdmin(address admin) external;

    function removeConnectorAdmin(address admin) external;

    function addRouterAdmin(address admin) external;

    function removeRouterAdmin(address admin) external;

    function isConnectorAdmin(address admin) external view returns (bool);

    function isRouterAdmin(address admin) external view returns (bool);
}
