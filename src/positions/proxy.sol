// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract CloneFactory {
    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target)<<16;
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602b80600a3d3981f3363d3d373d3d3d363d71000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x26), 0x5af43d82803e903d91602957fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x35)
        }
    }

    function isClone(address target, address query) internal view returns (bool result) {
        bytes20 targetBytes = bytes20(target)<<16;
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x363d3d373d3d3d363d7100000000000000000000000000000000000000000000)
            mstore(add(clone, 0xa), targetBytes)
            mstore(add(clone, 0x1c), 0x5af43d82803e903d91602957fd5bf30000000000000000000000000000000000)

            let other := add(clone, 0x40)
            extcodecopy(query, other, 0, 0x2b)

            result := and(
                eq(mload(clone), mload(other)), 
                eq(mload(add(clone, 0x20)), mload(add(other, 0x20)))
            )
        }
    }
}
