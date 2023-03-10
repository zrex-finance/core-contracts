// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { Proxy } from "../src/protocol/router/Proxy.sol";
import { Implementations } from "../src/protocol/configuration/Implementations.sol";

contract Impl {
    uint256 private count;

    function increaseCount() external {
        count++;
    }

    function getCount() external view returns (uint256) {
        return count;
    }
}

contract TestProxy is Test {
    Impl public impl;
    Proxy public proxy;
    Implementations public implementations;

    bytes32 public constant salt = 0x0000000000000000000000000000000000000000000000000000000047941987;

    function test_NotAbleFindImpl() public {
        address clone = Clones.cloneDeterministic(address(proxy), salt);
        vm.expectRevert(abi.encodePacked("23"));
        Impl(clone).increaseCount();
    }

    function test_callImpl_setDefaultImp() public {
        implementations.setDefaultImplementation(address(impl));
        address clone = Clones.cloneDeterministic(address(proxy), salt);

        uint256 initialCount = Impl(clone).getCount();
        Impl(clone).increaseCount();
        uint256 finalCount = Impl(clone).getCount();

        assertEq(1, finalCount - initialCount);
    }

    function test_callImpl_setImplSigs() public {
        bytes4[] memory _sigs = new bytes4[](2);
        _sigs[0] = impl.increaseCount.selector;
        _sigs[1] = impl.getCount.selector;

        implementations.addImplementation(address(impl), _sigs);
        address clone = Clones.cloneDeterministic(address(proxy), salt);

        uint256 initialCount = Impl(clone).getCount();
        Impl(clone).increaseCount();
        uint256 finalCount = Impl(clone).getCount();

        assertEq(1, finalCount - initialCount);
    }

    receive() external payable {}

    function setUp() public {
        impl = new Impl();
        implementations = new Implementations();
        proxy = new Proxy(address(implementations));
    }
}
