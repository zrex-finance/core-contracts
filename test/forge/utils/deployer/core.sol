// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IAddressesProvider } from 'src/interfaces/IAddressesProvider.sol';

import { Proxy } from 'src/Proxy.sol';
import { Account as AccountContract } from 'src/Account.sol';

import { IRouter } from 'src/interfaces/IRouter.sol';

import { Router } from 'src/Router.sol';
import { Configurator } from 'src/Configurator.sol';

import { ACLManager } from 'src/ACLManager.sol';
import { Connectors } from 'src/Connectors.sol';
import { AddressesProvider } from 'src/AddressesProvider.sol';

import { Tokens } from '../tokens.sol';

contract DeployCoreContracts is Tokens {
    Router public router;
    AccountContract public accountImpl;

    address public owner = makeAddr('owner');

    address public ACL_ADMIN = makeAddr('ACL_ADMIN');
    address public CONNECTOR_ADMIN = makeAddr('CONNECTOR_ADMIN');
    address public ROUTER_ADMIN = makeAddr('ROUTER_ADMIN');
    address public TREASURY = makeAddr('TREASURY');

    function deployContracts(string[] memory _names, address[] memory _connectors) public {
        vm.startPrank(owner);
        AddressesProvider addressesProvider = new AddressesProvider(owner);
        addressesProvider.setAddress(bytes32('ACL_ADMIN'), ACL_ADMIN);
        vm.stopPrank();

        ACLManager aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        Connectors connectors = new Connectors(address(addressesProvider));

        vm.startPrank(ACL_ADMIN);
        aclManager.addConnectorAdmin(CONNECTOR_ADMIN);
        aclManager.addRouterAdmin(ROUTER_ADMIN);
        vm.stopPrank();

        vm.startPrank(owner);
        addressesProvider.setAddress(bytes32('ACL_MANAGER'), address(aclManager));
        addressesProvider.setAddress(bytes32('CONNECTORS'), address(connectors));

        Configurator configurator = new Configurator();

        router = new Router(IAddressesProvider(address(addressesProvider)));
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
        router = Router(payable(addressesProvider.getRouter()));

        accountImpl = new AccountContract(address(addressesProvider));
        Proxy accountProxy = new Proxy(address(addressesProvider));

        addressesProvider.setAddress(bytes32('ACCOUNT'), address(accountImpl));
        addressesProvider.setAddress(bytes32('TREASURY'), TREASURY);
        addressesProvider.setAddress(bytes32('ACCOUNT_PROXY'), address(accountProxy));
        vm.stopPrank();

        vm.prank(CONNECTOR_ADMIN);
        configurator.addConnectors(_names, _connectors);

        vm.prank(ROUTER_ADMIN);
        configurator.setFee(3);
    }
}
