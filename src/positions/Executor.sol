// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IConnectors {
    function isConnectors(string[] calldata _names) external view returns (bool isOk, address[] memory _connectors);
    function isConnector(string calldata _name) external view returns (bool isOk, address _connector);
}

contract Executor {
    IConnectors public connectors;

	constructor(address _connectors) {
        connectors = IConnectors(_connectors);
    }

    function encodeAndExecute(bytes memory _merge, bytes memory _data) public returns (bytes memory response) {
        (string memory name, bytes memory _calldata) = abi.decode(_data, (string, bytes));
        response = execute(name, abi.encodePacked(_calldata, _merge));
    }

    function decodeAndExecute(bytes memory _data) public returns (bytes memory response) {
        (string memory name, bytes memory _calldata) = abi.decode(_data, (string, bytes));
        response = execute(name, _calldata);
    }

    function execute(string memory _targetName, bytes memory _data) internal returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(connectors).isConnector(_targetName);
        require(isOk, "not connector");

        response = _delegatecall(_target, _data);
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