// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IImplementations {
    function getImplementationOrDefault(bytes32 _version) external view returns (address);

    function setDefaultImplementation(address _defaultImplementation) external;

    function addImplementation(address _implementation, bytes32 _version) external;

    function getVersion(address _implementation) external view returns (bytes32);

    function getImplementation(bytes32 _version) external view returns (address);

    function removeImplementation(address _implementation) external;
}
