// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/**
 * @title Errors library
 * @author FlashFlow
 * @notice Defines the error messages emitted by the different contracts of the FlashFlow protocol
 */
library Errors {
    string public constant CALLER_NOT_ACCOUNT_OWNER = "1"; // The caller of the function is not a account owner
    string public constant CALLER_NOT_RECEIVER = "2"; // The caller of the function is not a account conntract
    string public constant CALLER_NOT_FLASH_AGGREGATOR = "3"; // The caller of the function is not a flash aggregatoor conntract
    string public constant CALLER_NOT_POSITION_OWNER = "4"; // The caller of the function is not a position owner
    string public constant INVALID_ADDRESSES_PROVIDER = "5"; // The address of the pool addresses provider is invalid
    string public constant INITIATOR_NOT_ACCOUNT = "6"; // The initiator of the flashloan is not a account contract
    string public constant CHARGE_FEE_NOT_COMPLETED = "7"; // Failed to charge the protocol fee
    string public constant ACCOUNT_DOES_NOT_EXIST = "9"; // The sender does not have an account
    string public constant INVALID_CHARGE_AMOUNT = "10"; // Invalid amount to charge fee
    string public constant NOT_CONNECTOR = "11"; // There is no connector with this name
    string public constant INVALID_CONNECTOR_ADDRESS = "12"; // The address of the connector is invalid
    string public constant INVALID_CONNECTORS_LENGTH = "13"; // The length of the connector array and their names are different
    string public constant CONNECTOR_ALREADY_EXIST = "14"; // A connector with this name already exists
    string public constant CONNECTOR_DOES_NOT_EXIST = "15"; // A connector with this name does not exist
    string public constant CALLER_NOT_ROUTER_CONFIGURATOR = "16"; // The caller of the function is not a router configurator
    string public constant INVALID_FEE_AMOUNT = "17"; // The fee amount is invalid
    string public constant INVALID_IMPLEMENTATION_ADDRESS = "18"; // The address of the implementation is invalid
}
