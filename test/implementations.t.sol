// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Implementations } from "../src/protocol/configuration/Implementations.sol";

contract TestImplementations is Test {
    Implementations implementations;

    bytes32 public version = "ProxyV1";

    address defaultImpl = 0x0000000000000000000000000000000000000002;

    function test_setDefaultImplementation() public {
        implementations.setDefaultImplementation(defaultImpl);

        assertEq(defaultImpl, implementations.defaultImplementation());
    }

    function test_setDefaultImplementation_with_0_address() public {
        vm.expectRevert(abi.encodePacked("13"));
        implementations.setDefaultImplementation(address(0));
    }

    function test_addImplementation() public {
        implementations.addImplementation(defaultImpl, version);

        assertEq(defaultImpl, implementations.getImplementation(version));
    }

    function test_getImplementationSigs() public {
        implementations.addImplementation(defaultImpl, version);

        bytes32 _newVersion = implementations.getVersion(defaultImpl);

        assertEq(version, _newVersion);
    }

    function test_addImplementation_with_0_address() public {
        vm.expectRevert(abi.encodePacked("13"));
        implementations.addImplementation(address(0), version);
    }

    function test_addImplementation_same_address() public {
        implementations.addImplementation(defaultImpl, version);
        vm.expectRevert(abi.encodePacked("15"));
        implementations.addImplementation(defaultImpl, version);
    }

    function test_addImplementation_same_version() public {
        implementations.addImplementation(defaultImpl, version);
        vm.expectRevert(abi.encodePacked("16"));
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp)))));
        implementations.addImplementation(addr, version);
    }

    function test_removeImplementation() public {
        implementations.addImplementation(defaultImpl, version);
        implementations.removeImplementation(defaultImpl);

        assertEq(address(0), implementations.getImplementation(version));
    }

    function test_removeImplementation_with_0_address() public {
        vm.expectRevert(abi.encodePacked("13"));
        implementations.removeImplementation(address(0));
    }

    function test_removeImplementation_not_found() public {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp)))));
        vm.expectRevert(abi.encodePacked("14"));
        implementations.removeImplementation(addr);
    }

    receive() external payable {}

    function setUp() public {
        implementations = new Implementations();
    }
}
