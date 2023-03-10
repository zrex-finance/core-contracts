// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Errors } from "../libraries/helpers/Errors.sol";

contract Implementations is Ownable {
    address public defaultImplementation;

    mapping(bytes4 => address) internal sigImplementations;
    mapping(address => bytes4[]) internal implementationSigs;

    event LogSetDefaultImplementation(address indexed oldImplementation, address indexed newImplementation);
    event LogAddImplementation(address indexed implementation, bytes4[] sigs);
    event LogRemoveImplementation(address indexed implementation, bytes4[] sigs);

    function getImplementation(bytes4 _sig) external view returns (address) {
        address _implementation = sigImplementations[_sig];
        return _implementation == address(0) ? defaultImplementation : _implementation;
    }

    function getImplementationSigs(address _impl) external view returns (bytes4[] memory) {
        return implementationSigs[_impl];
    }

    function getSigImplementation(bytes4 _sig) external view returns (address) {
        return sigImplementations[_sig];
    }

    function setDefaultImplementation(address _defaultImplementation) external onlyOwner {
        require(_defaultImplementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        defaultImplementation = _defaultImplementation;
        emit LogSetDefaultImplementation(defaultImplementation, _defaultImplementation);
    }

    function addImplementation(address _implementation, bytes4[] calldata _sigs) external onlyOwner {
        require(_implementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        require(implementationSigs[_implementation].length == 0, Errors.IMPLEMENTATION_ALREADY_EXIST);
        for (uint i = 0; i < _sigs.length; i++) {
            bytes4 _sig = _sigs[i];
            require(sigImplementations[_sig] == address(0), Errors.SIGNATURE_ALREADY_ADDED);
            sigImplementations[_sig] = _implementation;
        }
        implementationSigs[_implementation] = _sigs;
        emit LogAddImplementation(_implementation, _sigs);
    }

    function removeImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        require(implementationSigs[_implementation].length != 0, Errors.IMPLEMENTATION_DOES_NOT_EXIST);
        bytes4[] memory sigs = implementationSigs[_implementation];
        for (uint i = 0; i < sigs.length; i++) {
            bytes4 sig = sigs[i];
            delete sigImplementations[sig];
        }
        delete implementationSigs[_implementation];
        emit LogRemoveImplementation(_implementation, sigs);
    }
}
