// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Euler } from "../connectors/protocols/euler/main.sol";
import { AaveResolver } from "../connectors/protocols/aave/v2/main.sol";
import { CompoundV3Resolver } from "../connectors/protocols/compound/v3/main.sol";

import { Executor } from "./executor.sol";

contract Connector is Executor {

    Euler euler;
    AaveResolver aaveV2Resolver;
    CompoundV3Resolver compoundV3Resolver;

    constructor(
        address _euler,
        address _aaveV2Resolver,
        address _compoundV3Resolver
    ) {
        euler = Euler(_euler);
        aaveV2Resolver = AaveResolver(_aaveV2Resolver);
        compoundV3Resolver = CompoundV3Resolver(_compoundV3Resolver);
    }

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
            _delegatecall(
                address(aaveV2Resolver),
                abi.encodeWithSelector(aaveV2Resolver.deposit.selector, _token, _amt)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Resolver),
                abi.encodeWithSelector(compoundV3Resolver.deposit.selector, market, _token, _amt)
            );
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
            _delegatecall(
                address(aaveV2Resolver),
                abi.encodeWithSelector(aaveV2Resolver.borrow.selector, _token, _amt, rateMode)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Resolver),
                abi.encodeWithSelector(compoundV3Resolver.borrow.selector, market, _token, _amt)
            );
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
            _delegatecall(
                address(aaveV2Resolver),
                abi.encodeWithSelector(aaveV2Resolver.payback.selector, _token, _amt, rateMode)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Resolver),
                abi.encodeWithSelector(compoundV3Resolver.payback.selector, market, _token, _amt)
            );
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
            _delegatecall(
                address(aaveV2Resolver),
                abi.encodeWithSelector(aaveV2Resolver.withdraw.selector, _token, _amt)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Resolver),
                abi.encodeWithSelector(compoundV3Resolver.withdraw.selector, market, _token, _amt)
            );
        } else if (_route == 3) {
            (uint256 subAccount) = abi.decode(_customData, (uint256));
            euler.withdraw(subAccount, _token, _amt);
        } else {
            revert("route-does-not-exist");
        }
    }
}