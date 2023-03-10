// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IImplementations } from "../../interfaces/IImplementations.sol";
import { Errors } from "../libraries/helpers/Errors.sol";

contract Proxy {
    IImplementations public immutable implementations;

    constructor(address _implementations) {
        implementations = IImplementations(_implementations);
    }

    function _delegate(address implementation) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _fallback(bytes4 _sig) internal {
        address _implementation = implementations.getImplementation(_sig);
        require(_implementation != address(0), Errors.NOT_FOUND_IMPLEMENTATION);
        _delegate(_implementation);
    }

    fallback() external payable {
        _fallback(msg.sig);
    }

    receive() external payable {
        if (msg.sig != 0x00000000) {
            _fallback(msg.sig);
        }
    }
}
