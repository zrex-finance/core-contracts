// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Implementations } from "../src/protocol/configuration/Implementations.sol";

contract TestImplementations is Test {
    Implementations implementations;

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
        bytes4[] memory _sigs = new bytes4[](1);
        _sigs[0] = implementations.setDefaultImplementation.selector;

        implementations.addImplementation(defaultImpl, _sigs);

        assertEq(defaultImpl, implementations.getSigImplementation(_sigs[0]));
    }

    function test_getImplementationSigs() public {
        bytes4[] memory _sigs = new bytes4[](1);
        _sigs[0] = implementations.setDefaultImplementation.selector;

        implementations.addImplementation(defaultImpl, _sigs);

        bytes4[] memory _newSigs = implementations.getImplementationSigs(defaultImpl);

        assertEq(bytes32(_sigs[0]), bytes32(_newSigs[0]));
    }

    function test_addImplementation_with_0_address() public {
        bytes4[] memory _sigs = new bytes4[](1);
        _sigs[0] = implementations.setDefaultImplementation.selector;

        vm.expectRevert(abi.encodePacked("13"));
        implementations.addImplementation(address(0), _sigs);
    }

    function test_addImplementation_same_address() public {
        bytes4[] memory _sigs = new bytes4[](1);
        _sigs[0] = implementations.setDefaultImplementation.selector;

        implementations.addImplementation(defaultImpl, _sigs);
        vm.expectRevert(abi.encodePacked("15"));
        implementations.addImplementation(defaultImpl, _sigs);
    }

    function test_addImplementation_same_sig() public {
        bytes4[] memory _sigs = new bytes4[](1);
        _sigs[0] = implementations.setDefaultImplementation.selector;

        implementations.addImplementation(defaultImpl, _sigs);
        vm.expectRevert(abi.encodePacked("16"));
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp)))));
        implementations.addImplementation(addr, _sigs);
    }

    function test_removeImplementation() public {
        bytes4[] memory _sigs = new bytes4[](1);
        _sigs[0] = implementations.setDefaultImplementation.selector;

        implementations.addImplementation(defaultImpl, _sigs);
        implementations.removeImplementation(defaultImpl);

        assertEq(address(0), implementations.getSigImplementation(_sigs[0]));
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
