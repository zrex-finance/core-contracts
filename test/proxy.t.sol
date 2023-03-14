// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { Proxy } from "../src/protocol/router/Proxy.sol";
import { Implementations } from "../src/protocol/configuration/Implementations.sol";

contract Impl {
    uint256 public count;

    function increaseCount() external {
        count++;
    }

    function getCount() external view returns (uint256) {
        return count;
    }
}

contract ImplNew is Impl {
    function getIncreaseCount() external view returns (uint256) {
        return count + 10;
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

    function test_callImpl_setImplVersion() public {
        bytes32 _version = "ProxyV2";
        Proxy newProxy = new Proxy(address(implementations), _version);

        implementations.addImplementation(address(impl), _version);
        address clone = Clones.cloneDeterministic(address(newProxy), salt);

        uint256 initialCount = Impl(clone).getCount();
        Impl(clone).increaseCount();
        uint256 finalCount = Impl(clone).getCount();

        assertEq(1, finalCount - initialCount);
    }

    function test_callImpl_UpdateImpl() public {
        implementations.setDefaultImplementation(address(impl));
        address clone = Clones.cloneDeterministic(address(proxy), salt);

        uint256 initialCount = Impl(clone).getCount();
        Impl(clone).increaseCount();
        uint256 finalCount = Impl(clone).getCount();
        assertEq(1, finalCount - initialCount);

        ImplNew impl2 = new ImplNew();
        implementations.setDefaultImplementation(address(impl2));

        uint256 initialCount2 = ImplNew(clone).getCount();
        Impl(clone).increaseCount();
        uint256 finalCount2 = ImplNew(clone).getCount();
        uint256 increaseCount = ImplNew(clone).getIncreaseCount();
        assertEq(1, finalCount2 - initialCount2);
        assertEq(finalCount2 + 10, increaseCount);

        address clone2 = Clones.cloneDeterministic(
            address(proxy),
            0x0000000000000000000000000000000000000000000000000000000047941984
        );

        uint256 initialCountClone2 = ImplNew(clone2).getCount();
        uint256 increaseCountClone2 = ImplNew(clone2).getIncreaseCount();
        assertEq(0, initialCountClone2);
        assertEq(10, increaseCountClone2);
    }

    receive() external payable {}

    function setUp() public {
        bytes32 _version = "ProxyV1";

        impl = new Impl();
        implementations = new Implementations();
        proxy = new Proxy(address(implementations), _version);
    }
}
