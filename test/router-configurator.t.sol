// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "../src/dependencies/openzeppelin/contracts/ERC20.sol";
import { Clones } from "../src/dependencies/openzeppelin/upgradeability/Clones.sol";

import { Router } from "../src/protocol/router/Router.sol";
import { RouterConfigurator } from "../src/protocol/router/RouterConfigurator.sol";

import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

contract TestRouterConfigurator is Test {
    Router router;
    RouterConfigurator routerConfigurator;
    AddressesProvider addressesProvider;

    address testAddress;

    // Main identifiers
    function test_setFee() public {
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setRouterConfiguratorImpl(address(routerConfigurator));
        assertEq(Router(addressesProvider.getRouter()).fee(), 0);

        RouterConfigurator(addressesProvider.getRouterConfigurator()).setFee(5);
        assertEq(Router(addressesProvider.getRouter()).fee(), 5);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider();
        router = new Router(address(addressesProvider));
        routerConfigurator = new RouterConfigurator();
    }
}
