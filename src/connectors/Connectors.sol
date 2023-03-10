// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IConnector } from "./interfaces/Connectors.sol";

contract Connectors is Ownable {
    mapping(string => address) public connectors;

    function addConnectors(string[] calldata _names, address[] calldata _connectors) external onlyOwner {
        require(_names.length == _connectors.length, "not same length");

        for (uint i = 0; i < _connectors.length; i++) {
            require(connectors[_names[i]] == address(0), "name added already");
            require(_connectors[i] != address(0), "connectors address not vaild");
            IConnector(_connectors[i]).name();
            connectors[_names[i]] = _connectors[i];
        }
    }

    function updateConnectors(string[] calldata _names, address[] calldata _connectors) external onlyOwner {
        require(_names.length == _connectors.length, "not same length");

        for (uint i = 0; i < _connectors.length; i++) {
            require(connectors[_names[i]] != address(0), "name not added to update");
            require(_connectors[i] != address(0), "connector address is not vaild");
            IConnector(_connectors[i]).name();
            connectors[_names[i]] = _connectors[i];
        }
    }

    function removeConnectors(string[] calldata _names) external onlyOwner {
        for (uint i = 0; i < _names.length; i++) {
            require(connectors[_names[i]] != address(0), "name not added to update");
            delete connectors[_names[i]];
        }
    }

    function isConnectors(string[] calldata _names) external view returns (bool isOk, address[] memory _connectors) {
        isOk = true;
        uint len = _names.length;
        _connectors = new address[](len);

        for (uint i = 0; i < _connectors.length; i++) {
            _connectors[i] = connectors[_names[i]];
            if (_connectors[i] == address(0)) {
                isOk = false;
                break;
            }
        }
    }

    function isConnector(string calldata _name) external view returns (bool isOk, address _connector) {
        isOk = true;
        _connector = connectors[_name];

        if (_connector == address(0)) {
            isOk = false;
        }
    }
}
