// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

contract TestAddressesProvider is Test {
    AddressesProvider addressesProvider;

    address public testAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function test_setAddress_Router() public {
        addressesProvider.setAddress(bytes32("ROUTER"), testAddress);
        assertEq(addressesProvider.getRouter(), testAddress);
    }

    function test_setAddress_Treasury() public {
        addressesProvider.setAddress(bytes32("TREASURY"), testAddress);
        assertEq(addressesProvider.getTreasury(), testAddress);
    }

    function test_setAddress_Connectors() public {
        addressesProvider.setAddress(bytes32("CONNECTORS"), testAddress);
        assertEq(addressesProvider.getConnectors(), testAddress);
    }

    function test_setAddress_AccountProxy() public {
        addressesProvider.setAddress(bytes32("ACCOUNT_PROXY"), testAddress);
        assertEq(addressesProvider.getAccountProxy(), testAddress);
    }

    function test_setAddress_Implementations() public {
        addressesProvider.setAddress(bytes32("IMPLEMENTATIONS"), testAddress);
        assertEq(addressesProvider.getImplementations(), testAddress);
    }

    function test_setAddress_FlashloanAggregator() public {
        addressesProvider.setAddress(bytes32("FLASHLOAN_AGGREGATOR"), testAddress);
        assertEq(addressesProvider.getFlashloanAggregator(), testAddress);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider();
    }
}
