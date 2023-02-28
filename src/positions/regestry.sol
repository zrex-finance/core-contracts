// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";

interface AccountInterface {
    function execute(
        address[] calldata _targets,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (bytes32[] memory responses);
}

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

contract Regestry is CloneFactory {

    address public immutable accountProxy;

    // user -> account proxy
    mapping (address => address) public accounts;

    constructor(address _accountProxy) {
        accountProxy = _accountProxy;
    }

    function createWithExecute(
        address _owner,
        address[] calldata _targets,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (address _account) {
        _account = createAccount(_owner);

        if (_targets.length > 0) {
            AccountInterface(_account).execute{value: msg.value}(_targets, _datas, _origin);
        }
    }

    function createAccount(address _owner) public returns (address _account) {
        require(_owner == msg.sender, "sender not owner");
        _account = address(accounts[_owner]);

        require(_account == address(0), "account already exists");
        _account = Clones.clone(accountProxy);
        accounts[_owner] = _account;
    }
}