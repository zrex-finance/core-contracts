// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library Errors {
    string public constant CALLER_NOT_ACCOUNT_OWNER = "1";
    string public constant CALLER_NOT_RECEIVER = "2";
    string public constant CALLER_NOT_FLASH_AGGREGATOR = "3";
    string public constant CALLER_NOT_POSITION_OWNER = "4";
    string public constant INVALID_ADDRESSES_PROVIDER = "5";
    string public constant NOT_CONNECTOR = "6";
    string public constant INVALID_CONNECTOR_ADDRESS = "7";
    string public constant INITIATOR_NOT_ACCOUNT = "8";
    string public constant CHARGE_FEE_NOT_COMPLETED = "9";
    string public constant INVALID_CONNECTORS_LENGTH = "10";
    string public constant CONNECTOR_ALREADY_EXIST = "11";
    string public constant CONNECTOR_DOES_NOT_EXIST = "12";
    string public constant INVALID_IMPLEMENTATION_ADDRESS = "13";
    string public constant IMPLEMENTATION_DOES_NOT_EXIST = "14";
    string public constant IMPLEMENTATION_ALREADY_EXIST = "15";
    string public constant SIGNATURE_ALREADY_ADDED = "16";
    string public constant TOKENS_HAS_DIFERENT_LENGTH = "17";
    string public constant MAPPING_ALREADY_ADDED = "18";
    string public constant INVALID_TOKEN_ADDRESS = "19";
    string public constant INVALID_CTOKEN_ADDRESS = "20";
    string public constant NOT_CTOKEN = "21";
    string public constant MAPPING_MISMATCH = "22";
    string public constant NOT_FOUND_IMPLEMENTATION = "23";
    string public constant ACCOUNT_DOES_NOT_EXIST = "24";
    string public constant INVALID_AMOUNT = "25";
}
