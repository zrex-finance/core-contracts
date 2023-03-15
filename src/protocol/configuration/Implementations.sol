// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Errors } from "../libraries/helpers/Errors.sol";

contract Implementations is Ownable {
    address public defaultImplementation;

    mapping(bytes32 => address) internal versionToImplementation;
    mapping(address => bytes32) internal implementationToVersion;

    event LogSetDefaultImplementation(address indexed oldImplementation, address indexed newImplementation);
    event LogAddImplementation(address indexed implementation, bytes32 version);
    event LogRemoveImplementation(address indexed implementation, bytes32 version);

    function getImplementationOrDefault(bytes32 _version) external view returns (address) {
        address _implementation = versionToImplementation[_version];
        return _implementation == address(0) ? defaultImplementation : _implementation;
    }

    function getVersion(address _implementation) external view returns (bytes32) {
        return implementationToVersion[_implementation];
    }

    function getImplementation(bytes32 _version) external view returns (address) {
        return versionToImplementation[_version];
    }

    function setDefaultImplementation(address _defaultImplementation) external onlyOwner {
        require(_defaultImplementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        defaultImplementation = _defaultImplementation;
        emit LogSetDefaultImplementation(defaultImplementation, _defaultImplementation);
    }

    function addImplementation(address _implementation, bytes32 _version) external onlyOwner {
        require(_implementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        require(implementationToVersion[_implementation] == 0, Errors.IMPLEMENTATION_ALREADY_EXIST);
        require(versionToImplementation[_version] == address(0), Errors.VERSION_ALREADY_ADDED);

        versionToImplementation[_version] = _implementation;
        implementationToVersion[_implementation] = _version;
        emit LogAddImplementation(_implementation, _version);
    }

    function removeImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        require(implementationToVersion[_implementation] != 0, Errors.IMPLEMENTATION_DOES_NOT_EXIST);
        bytes32 version = implementationToVersion[_implementation];

        delete versionToImplementation[version];
        delete implementationToVersion[_implementation];
        emit LogRemoveImplementation(_implementation, version);
    }
}
