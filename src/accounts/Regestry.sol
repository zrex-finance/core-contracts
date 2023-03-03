// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SharedStructs } from "../lib/SharedStructs.sol";
import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { IAccount } from "./interfaces/Regestry.sol";

contract Regestry {
    using UniversalERC20 for IERC20;

    address public accountProxy;
    address public positionRouter;

   bytes32 public constant salt = 0x0000000000000000000000000000000000000000000000000000000047941987; 

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

        if (!isShort) {
			IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
		}
        IERC20(position.debt).universalApprove(_account, position.amountIn);

        IAccount(_account).openPosition{value: msg.value}(
            position, isShort, _tokens, _amts, route, _data, _customData
        );
    }

    function createAccount(address _owner) public returns (address _account) {
        require(_owner == msg.sender, "sender not owner");
        _account = address(accounts[_owner]);

        require(_account == address(0), "account already exists");
        _account = Clones.cloneDeterministic(accountProxy, salt);
        IAccount(_account).initialize(positionRouter);
        accounts[_owner] = _account;
    }

    function predictDeterministicAddress() public view returns (address predicted) {
        return Clones.predictDeterministicAddress(accountProxy, salt, address(this));
    }
}