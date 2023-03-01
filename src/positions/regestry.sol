// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";

import { SharedStructs, IAccount } from "./interfaces.sol";

contract Regestry {

    address public accountProxy;
    address public positionRouter;

    // user -> account proxy
    mapping (address => address) public accounts;

    constructor(address _accountProxy, address _positionRouter) {
        accountProxy = _accountProxy;
        positionRouter = _positionRouter;
    }

    function createWithOpen(
        SharedStructs.Position memory position,
        bool isShort,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable returns (address _account) {
        _account = createAccount(msg.sender);

        IAccount(_account).openPosition{value: msg.value}(
            position, isShort, _tokens, _amts, route, _data, _customData
        );
    }

    function createAccount(address _owner) public returns (address _account) {
        require(_owner == msg.sender, "sender not owner");
        _account = address(accounts[_owner]);

        require(_account == address(0), "account already exists");
        _account = Clones.clone(accountProxy);
        IAccount(_account).initialize(positionRouter);
        accounts[_owner] = _account;
    }
}