// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IImplementations {
    function getImplementation(bytes4 _sig) external view returns (address);

    function getImplementationSigs(address _impl) external view returns (bytes4[] memory);

    function getSigImplementation(bytes4 _sig) external view returns (address);

    function setDefaultImplementation(address _defaultImplementation) external;

    function addImplementation(address _implementation, bytes4[] calldata _sigs) external;

    function removeImplementation(address _implementation) external;
}
