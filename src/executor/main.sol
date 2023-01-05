// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ConnectorsInterface } from "./interface.sol";
import { TokenReceiver } from "./helpers.sol";

contract ExecutorImplementation is TokenReceiver {
  address public immutable connectors;

  constructor(address _connectors) {
    connectors = _connectors;
  }

  function decodeEvent(bytes memory response) internal pure returns (string memory _eventCode, bytes memory _eventParams) {
    if (response.length > 0) {
      (_eventCode, _eventParams) = abi.decode(response, (string, bytes));
    }
  }

  event LogCast(
    address indexed origin,
    address indexed sender,
    uint256 value,
    string[] targetsNames,
    address[] targets,
    string[] eventNames,
    bytes[] eventParams
  );

  receive() external payable {}

  function execute(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external payable {
    uint256 _length = _targetNames.length;
    require(_length != 0, "Length invalid");
    require(_length == _datas.length , "Array has different lenght");

    string[] memory eventNames = new string[](_length);
    bytes[] memory eventParams = new bytes[](_length);

    (bool isOk, address[] memory _targets) = ConnectorsInterface(connectors).isConnectors(_targetNames);

    require(isOk, "Target is not connector");

    for (uint i = 0; i < _length; i++) {
      bytes memory response = _delegatecall(_targets[i], _datas[i]);
      (eventNames[i], eventParams[i]) = decodeEvent(response);
    }

    emit LogCast(
      _origin,
      msg.sender,
      msg.value,
      _targetNames,
      _targets,
      eventNames,
      eventParams
    );
  }

  // internal

  function _delegatecall(address _target, bytes memory _data) internal returns (bytes memory response) {
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
