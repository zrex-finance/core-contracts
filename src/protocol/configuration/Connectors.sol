// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IConnector } from "../../interfaces/IConnector.sol";

import { Errors } from "../libraries/helpers/Errors.sol";

/**
 * @title Connectors
 * @author FlashFlow
 * @notice Contract to manage and store auxiliary contracts to work with the necessary protocols
 */
contract Connectors is Ownable {
    // Enabled Connectors(Connector name => address).
    mapping(string => address) private connectors;

    /**
     * @dev Add Connectors
     * @param _names Array of Connector Names.
     * @param _connectors Array of Connector Address.
     */
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

    /**
     * @dev Update Connectors
     * @param _names Array of Connector Names.
     * @param _connectors Array of Connector Address.
     */
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

    /**
     * @dev Remove Connectors
     * @param _names Array of Connector Names.
     */
    function removeConnectors(string[] calldata _names) external onlyOwner {
        for (uint i = 0; i < _names.length; i++) {
            string memory name = _names[i];

            require(connectors[name] != address(0), Errors.CONNECTOR_DOES_NOT_EXIST);
            delete connectors[name];
        }
    }

    /**
     * @dev Check if Connector addresses are enabled.
     * @param _name Connector Name.
     */
    function isConnector(string calldata _name) external view returns (bool isOk, address connector) {
        isOk = true;
        connector = connectors[_name];

        if (connector == address(0)) {
            isOk = false;
        }
    }
}
