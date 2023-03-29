// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from '../contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { Clones } from '../contracts/dependencies/openzeppelin/upgradeability/Clones.sol';

import { AddressesProvider } from '../contracts/AddressesProvider.sol';
import { IAddressesProvider } from '../contracts/interfaces/IAddressesProvider.sol';

import { Account } from '../contracts/Account.sol';

contract TestAccount is Test {
    Account account;

    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;
    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    mapping(uint => address) public test2;

    // Main identifiers
    function test_claimERC20Token() public {
        uint256 amount = 1000 ether;

        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(account), amount);

        uint256 balanceBefore = ERC20(daiC).balanceOf(msg.sender);
        vm.prank(msg.sender);
        account.claimTokens(daiC, amount);
        uint256 balanceAfter = ERC20(daiC).balanceOf(msg.sender);

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_claimERC20Token_Max() public {
        uint256 amount = 1000 ether;

        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(account), amount);

        uint256 balanceBefore = ERC20(daiC).balanceOf(msg.sender);
        vm.prank(msg.sender);
        account.claimTokens(daiC, 0);
        uint256 balanceAfter = ERC20(daiC).balanceOf(msg.sender);

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_claimEther() public {
        uint256 amount = 1 ether;

        payable(address(account)).transfer(amount);

        uint256 balanceBefore = address(msg.sender).balance;
        vm.prank(msg.sender);
        account.claimTokens(address(0), amount);
        uint256 balanceAfter = address(msg.sender).balance;

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_claimEther_Max() public {
        uint256 amount = 1 ether;

        payable(address(account)).transfer(amount);

        uint256 balanceBefore = address(msg.sender).balance;
        vm.prank(msg.sender);
        account.claimTokens(address(0), 0);
        uint256 balanceAfter = address(msg.sender).balance;

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_executeOperation_Revert() public {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(0);

        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = uint256(1 ether);

        uint256[] memory _premiums = new uint256[](1);
        _premiums[0] = uint256(1 ether);

        bytes[] memory _bytes = new bytes[](1);
        _bytes[0] = bytes('');

        string[] memory _strings = new string[](1);
        _strings[0] = string('');

        vm.expectRevert(bytes(''));
        vm.prank(daiC);
        account.executeOperation(
            _tokens,
            _amounts,
            _premiums,
            address(account),
            abi.encode(bytes4(''), _strings, _bytes, _bytes)
        );
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        address addressesProvider = address(new AddressesProvider(address(this)));

        AddressesProvider(addressesProvider).setAddress(bytes32('FLASHLOAN_AGGREGATOR'), daiC);

        account = new Account(addressesProvider);
        account.initialize(msg.sender, IAddressesProvider(addressesProvider));
    }
}
