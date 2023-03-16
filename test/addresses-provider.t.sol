// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "../src/dependencies/openzeppelin/contracts/ERC20.sol";
import { Clones } from "../src/dependencies/openzeppelin/upgradeability/Clones.sol";

import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

interface IProxy {
    function admin() external returns (address);
}

contract DummyContract {
    uint256 public count = 1;

    function initialize(address provider) external {}
}

contract TestAddressesProvider is Test {
    AddressesProvider addressesProvider;

    address testAddress;

    // Main identifiers
    function test_setAddress_RouterConfigurator() public {
        addressesProvider.setRouterConfiguratorImpl(testAddress);
        assertTrue(addressesProvider.getRouterConfigurator() != address(0));
    }

    function test_updateAddress_RouterConfigurator() public {
        addressesProvider.setRouterConfiguratorImpl(testAddress);
        assertTrue(addressesProvider.getRouterConfigurator() != address(0));

        address newTestContract = address(new DummyContract());

        addressesProvider.setRouterConfiguratorImpl(newTestContract);
        assertTrue(
            addressesProvider.getRouterConfigurator() != address(0) &&
                addressesProvider.getRouterConfigurator() != testAddress
        );
    }

    function test_setAddress_Router() public {
        addressesProvider.setRouterImpl(testAddress);
        assertTrue(addressesProvider.getRouter() != address(0));
    }

    function test_setAddress_Account() public {
        addressesProvider.setAddress(bytes32("ACCOUNT"), testAddress);
        assertEq(addressesProvider.getAccountImpl(), testAddress);
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

    function test_setAddress_FlashloanAggregator() public {
        addressesProvider.setAddress(bytes32("FLASHLOAN_AGGREGATOR"), testAddress);
        assertEq(addressesProvider.getFlashloanAggregator(), testAddress);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider();
        testAddress = address(new DummyContract());
    }
}
