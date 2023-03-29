// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IMapping {
    function addCtokenMapping(address[] memory _tokens, address[] memory _ctokens) external;

    function getMapping(address _token) external view returns (address, address);

    function name() external view returns (string memory);

    function cTokenMapping(address _token) external returns (address);
}
