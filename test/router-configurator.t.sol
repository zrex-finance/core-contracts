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

contract ConnectorImpl {
    string public constant name = "ConnectorImpl";
}

contract TestConfigurator is Test {
    Router router;
    Configurator configurator;
    Connectors connectors;
    ACLManager aclManager;
    AddressesProvider addressesProvider;

    address testAddress;

    // Main identifiers
    function test_setFee() public {
        aclManager.addRouterAdmin(address(this));
        _setFee();
    }

    function test_setFee_EmergencyAdmin() public {
        aclManager.addEmergencyAdmin(address(this));
        _setFee();
    }

    function test_addConnectors() public {
        aclManager.addConnectorAdmin(address(this));
        _addConnectors();
    }

    function test_addConnectors_EmergencyAdmin() public {
        aclManager.addEmergencyAdmin(address(this));
        _addConnectors();
    }

    function _setFee() public {
        assertEq(router.fee(), 0);

        configurator.setFee(5);
        assertEq(router.fee(), 5);
    }

    function _addConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        configurator.addConnectors(_names, _connectors);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider();
        addressesProvider.setAddress(bytes32("ACL_ADMIN"), address(this));

        aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

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
