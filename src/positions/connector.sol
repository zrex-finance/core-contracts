// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Euler } from "../connectors/protocols/euler/main.sol";
import { AaveResolver } from "../connectors/protocols/aave/v2/main.sol";
import { CompoundV3Resolver } from "../connectors/protocols/compound/v3/main.sol";

contract Connector {

    Euler internal constant euler = Euler(address(0));
    AaveResolver internal constant aaveV2Resolver = AaveResolver(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);
    CompoundV3Resolver internal constant compoundV3Resolver = CompoundV3Resolver(address(0));

    function deposit(uint256 _amt, bytes memory _data) public payable {
        (
            address _token,
            uint256 _route,
            bytes memory _customData
        ) = abi.decode(_data, (address, uint256, bytes));
        _deposit(_amt, _token, _route, _customData);
    }

    function _deposit(
        uint256 _amt,
        address _token,
        uint256 _route,
        bytes memory _customData
    ) internal {
        if (_route == 1) {
            aaveV2Resolver.deposit(_token, _amt); // delegate call
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            compoundV3Resolver.deposit(market, _token, _amt);
        } else if (_route == 3) {
            (uint256 subAccount, bool enableCollateral) = abi.decode(_customData, (uint256, bool));
            euler.deposit(subAccount, _token, _amt, enableCollateral);
        } else {
            revert("route-does-not-exist");
        }
    }

    function borrow(uint256 _amt, bytes memory _data) public payable {
        (
            address _token,
            uint256 _route,
            bytes memory _customData
        ) = abi.decode(_data, (address, uint256, bytes));
        _borrow(_amt, _token, _route, _customData);
    }

    function _borrow(
        uint256 _amt,
        address _token,
        uint256 _route,
        bytes memory _customData
    ) internal {
        if (_route == 1) {
            uint256 rateMode = abi.decode(_customData, (uint256));
            aaveV2Resolver.borrow(_token, _amt, rateMode);
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            compoundV3Resolver.borrow(market, _token, _amt);
        } else if (_route == 3) {
            (uint256 subAccount) = abi.decode(_customData, (uint256));
            euler.borrow(subAccount, _token, _amt);
        } else {
            revert("route-does-not-exist");
        }
    }

    function payback(bytes memory _data) public payable {
        (
            uint256 _amt,
            address _token,
            uint256 _route,
            bytes memory _customData
        ) = abi.decode(_data, (uint256, address, uint256, bytes));
        _payback(_amt, _token, _route, _customData);
    }

    function _payback(
        uint256 _amt,
        address _token,
        uint256 _route,
        bytes memory _customData
    ) internal {
        if (_route == 1) {
            uint256 rateMode = abi.decode(_customData, (uint256));
            aaveV2Resolver.payback(_token, _amt, rateMode);
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            compoundV3Resolver.payback(market, _token, _amt);
        } else if (_route == 3) {
            (uint256 subAccount) = abi.decode(_customData, (uint256));
            euler.repay(subAccount, _token, _amt);
        } else {
            revert("route-does-not-exist");
        }
    }

    function withdraw(bytes memory _data) public payable {
        (
            uint256 _amt,
            address _token,
            uint256 _route,
            bytes memory _customData
        ) = abi.decode(_data, (uint256, address, uint256, bytes));
        _withdraw(_amt, _token, _route, _customData);
    }

    function _withdraw(
        uint256 _amt,
        address _token,
        uint256 _route,
        bytes memory _customData
    ) internal {
        if (_route == 1) {
            aaveV2Resolver.withdraw(_token, _amt);
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            compoundV3Resolver.withdraw(market, _token, _amt);
        } else if (_route == 3) {
            (uint256 subAccount) = abi.decode(_customData, (uint256));
            euler.withdraw(subAccount, _token, _amt);
        } else {
            revert("route-does-not-exist");
        }
    }
}