// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IACLManager {
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function addConnectorAdmin(address admin) external;

    function removeConnectorAdmin(address admin) external;

    function addRouterAdmin(address admin) external;

    function removeRouterAdmin(address admin) external;

    function addReferralAdmin(address admin) external;

    function removeReferralAdmin(address admin) external;

    function isConnectorAdmin(address admin) external view returns (bool);

    function isRouterAdmin(address admin) external view returns (bool);

    function isReferralAdmin(address admin) external view returns (bool);

    function addAssetListingAdmin(address admin) external;

    function removeAssetListingAdmin(address admin) external;

    function isAssetListingAdmin(address admin) external view returns (bool);
}
