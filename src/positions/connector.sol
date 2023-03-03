// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { EulerConnector } from "../connectors/Euler.sol";
import { AaveV2Connector } from "../connectors/AaveV2.sol";
import { CompoundV3Connector } from "../connectors/CompoundV3.sol";

contract Connector {

    EulerConnector internal euler;
    AaveV2Connector internal aaveV2connector;
    CompoundV3Connector internal compoundV3Connector;

    constructor(
        address _euler,
        address _aaveV2connector,
        address _compoundV3Connector
    ) {
        euler = EulerConnector(_euler);
        aaveV2connector = AaveV2Connector(_aaveV2connector);
        compoundV3Connector = CompoundV3Connector(_compoundV3Connector);
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
                address(aaveV2connector),
                abi.encodeWithSelector(aaveV2connector.deposit.selector, _token, _amt)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Connector),
                abi.encodeWithSelector(compoundV3Connector.deposit.selector, market, _token, _amt)
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
                address(aaveV2connector),
                abi.encodeWithSelector(aaveV2connector.borrow.selector, _token, _amt, rateMode)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Connector),
                abi.encodeWithSelector(compoundV3Connector.borrow.selector, market, _token, _amt)
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
                address(aaveV2connector),
                abi.encodeWithSelector(aaveV2connector.payback.selector, _token, _amt, rateMode)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Connector),
                abi.encodeWithSelector(compoundV3Connector.payback.selector, market, _token, _amt)
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
                address(aaveV2connector),
                abi.encodeWithSelector(aaveV2connector.withdraw.selector, _token, _amt)
            );
        } else if (_route == 2) {
            address market = abi.decode(_customData, (address));
            _delegatecall(
                address(compoundV3Connector),
                abi.encodeWithSelector(compoundV3Connector.withdraw.selector, market, _token, _amt)
            );
        } else if (_route == 3) {
            (uint256 subAccount) = abi.decode(_customData, (uint256));
            euler.withdraw(subAccount, _token, _amt);
        } else {
            revert("route-does-not-exist");
        }
    }

    function _delegatecall(
		address _target,
		bytes memory _data
	) internal returns (bytes memory response) {
		require(_target != address(0), "Target invalid");
		assembly {
			let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)
			let size := returndatasize()

			response := mload(0x40)
			mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
			mstore(response, size)
			returndatacopy(add(response, 0x20), 0, size)

			switch iszero(succeeded)
			case 1 {
				// throw if delegatecall failed
				returndatacopy(0x00, 0x00, size)
				revert(0x00, size)
			}
		}
	}
}