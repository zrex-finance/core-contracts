// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Implementations } from "../src/accounts/Implementations.sol";

contract TestImplementations is Test {

  Implementations implementations;

  address defaultImpl = 0x0000000000000000000000000000000000000002;

  function test_setDefaultImplementation() public {
    implementations.setDefaultImplementation(defaultImpl);

    assertEq(defaultImpl, implementations.defaultImplementation());
  }

  function test_setDefaultImplementation_with_0_address() public {
    vm.expectRevert(abi.encodePacked("address not valid"));
    implementations.setDefaultImplementation(address(0));
  }

  function test_setDefaultImplementation_same_address() public {
    implementations.setDefaultImplementation(defaultImpl);

    vm.expectRevert(abi.encodePacked("cannot be same"));
    implementations.setDefaultImplementation(defaultImpl);
  }

  function test_setDefaultImplementation_emit_event() public {
    vm.expectEmit(true, true);
    implementations.setDefaultImplementation(defaultImpl);
  }

  receive() external payable {}

  function setUp() public {
    implementations = new Implementations();
  }
}