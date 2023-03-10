// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

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
        require(_defaultImplementation != address(0), "address not valid");
        require(_defaultImplementation != defaultImplementation, "cannot be same");
        emit LogSetDefaultImplementation(defaultImplementation, _defaultImplementation);
        defaultImplementation = _defaultImplementation;
    }

    function addImplementation(address _implementation, bytes4[] calldata _sigs) external onlyOwner {
        require(_implementation != address(0), "not valid");
        require(implementationSigs[_implementation].length == 0, "already added");
        for (uint i = 0; i < _sigs.length; i++) {
            bytes4 _sig = _sigs[i];
            require(sigImplementations[_sig] == address(0), "_sig already added");
            sigImplementations[_sig] = _implementation;
        }
        implementationSigs[_implementation] = _sigs;
        emit LogAddImplementation(_implementation, _sigs);
    }

    function removeImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "not valid");
        require(implementationSigs[_implementation].length != 0, "not found");
        bytes4[] memory sigs = implementationSigs[_implementation];
        for (uint i = 0; i < sigs.length; i++) {
            bytes4 sig = sigs[i];
            delete sigImplementations[sig];
        }
        delete implementationSigs[_implementation];
        emit LogRemoveImplementation(_implementation, sigs);
    }
}
