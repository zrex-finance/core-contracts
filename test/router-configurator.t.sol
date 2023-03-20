// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "../src/dependencies/openzeppelin/contracts/ERC20.sol";
import { Clones } from "../src/dependencies/openzeppelin/upgradeability/Clones.sol";

import { IAddressesProvider } from "../src/interfaces/IAddressesProvider.sol";

import { Router } from "../src/protocol/router/Router.sol";
import { Configurator } from "../src/protocol/configuration/Configurator.sol";

import { Connectors } from "../src/protocol/configuration/Connectors.sol";
import { ACLManager } from "../src/protocol/configuration/ACLManager.sol";
import { Configurator } from "../src/protocol/configuration/Configurator.sol";
import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

contract TestConfigurator is Test {
    Router router;
    Configurator configurator;
    Connectors connectors;
    AddressesProvider addressesProvider;

    address testAddress;

    // Main identifiers
    function test_setFee() public {
        assertEq(router.fee(), 0);

        configurator.setFee(5);
        assertEq(router.fee(), 5);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider();
        addressesProvider.setAddress(bytes32("ACL_ADMIN"), address(this));

        ACLManager aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

        aclManager.addEmergencyAdmin(address(this));
        aclManager.addRouterAdmin(address(this));

        addressesProvider.setAddress(bytes32("ACL_MANAGER"), address(aclManager));
        addressesProvider.setAddress(bytes32("CONNECTORS"), address(connectors));

        configurator = new Configurator();

        router = new Router(address(addressesProvider));
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
        router = Router(addressesProvider.getRouter());
    }
}
