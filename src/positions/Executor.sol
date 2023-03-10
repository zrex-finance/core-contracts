// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { IConnectors } from "./interfaces/PositionRouter.sol";

contract Executor is Initializable {
    IConnectors public connectors;

    function __Executor_init(address _connectors) internal onlyInitializing {
        connectors = IConnectors(_connectors);
    }

    function execute(string memory _targetName, bytes memory _data) internal returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(connectors).isConnector(_targetName);
        require(isOk, "not connector");

        response = _delegatecall(_target, _data);
    }

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
