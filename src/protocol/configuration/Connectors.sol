// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IConnector } from "../../interfaces/IConnector.sol";

import { Errors } from "../libraries/helpers/Errors.sol";

contract Connectors is Ownable {
    mapping(string => address) private connectors;

    function getConnector(string memory _name) public view returns (address) {
        return connectors[_name];
    }

    function addConnectors(string[] calldata _names, address[] calldata _connectors) external onlyOwner {
        require(_names.length == _connectors.length, Errors.INVALID_CONNECTORS_LENGTH);

        for (uint i = 0; i < _connectors.length; i++) {
            string memory name = _names[i];
            address connector = _connectors[i];

            require(connectors[name] == address(0), Errors.CONNECTOR_ALREADY_EXIST);
            require(connector != address(0), Errors.INVALID_CONNECTOR_ADDRESS);
            IConnector(connector).name();
            connectors[name] = connector;
        }
    }

    function updateConnectors(string[] calldata _names, address[] calldata _connectors) external onlyOwner {
        require(_names.length == _connectors.length, Errors.INVALID_CONNECTORS_LENGTH);

        for (uint i = 0; i < _connectors.length; i++) {
            string memory name = _names[i];
            address connector = _connectors[i];

            require(connectors[name] != address(0), Errors.CONNECTOR_DOES_NOT_EXIST);
            require(connector != address(0), Errors.INVALID_CONNECTOR_ADDRESS);
            IConnector(connector).name();
            connectors[name] = connector;
        }
    }

    function removeConnectors(string[] calldata _names) external onlyOwner {
        for (uint i = 0; i < _names.length; i++) {
            string memory name = _names[i];

            require(connectors[name] != address(0), Errors.CONNECTOR_DOES_NOT_EXIST);
            delete connectors[name];
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
