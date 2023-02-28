// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract Implementation is Test {

    function decodeEvent(
		bytes memory response
	) internal pure returns (string memory _eventCode, bytes memory _eventParams) {
		if (response.length > 0) {
			(_eventCode, _eventParams) = abi.decode(response, (string, bytes));
		}
	}

	event LogCast(
		address indexed origin,
		address indexed sender,
		uint256 value,
		address[] targets,
		string[] eventNames,
		bytes[] eventParams
	);

    receive() external payable {}

    function execute(
		address[] memory _targets,
		bytes[] memory _datas,
		address _origin
	) public payable {
		uint256 _length = _targets.length;
		require(_length != 0, "Length invalid");
		require(_length == _datas.length , "Array has different lenght");

		string[] memory eventNames = new string[](_length);
		bytes[] memory eventParams = new bytes[](_length);

		for (uint i = 0; i < _length; i++) {
			bytes memory response = _delegatecall(_targets[i], _datas[i]);
			(eventNames[i], eventParams[i]) = decodeEvent(response);
		}

		emit LogCast(
			_origin,
			msg.sender,
			msg.value,
			_targets,
			eventNames,
			eventParams
		);
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