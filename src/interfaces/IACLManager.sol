// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IACLManager {
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function addEmergencyAdmin(address admin) external;

    function removeEmergencyAdmin(address admin) external;

    function isEmergencyAdmin(address admin) external view returns (bool);

    function addRouterAdmin(address admin) external;

    function removeRouterAdmin(address admin) external;

    function isRouterAdmin(address admin) external view returns (bool);

    function addConnectorAdmin(address admin) external;

    function removeConnectorAdmin(address admin) external;

    function isConnectorAdmin(address admin) external view returns (bool);
}
