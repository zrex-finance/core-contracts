// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { IAddressesProvider } from 'contracts/interfaces/IAddressesProvider.sol';

import { Proxy } from 'contracts/Proxy.sol';
import { Account } from 'contracts/Account.sol';

import { IRouter } from 'contracts/interfaces/IRouter.sol';

import { Router } from 'contracts/Router.sol';
import { Configurator } from 'contracts/Configurator.sol';

import { ACLManager } from 'contracts/ACLManager.sol';
import { Connectors } from 'contracts/Connectors.sol';
import { AddressesProvider } from 'contracts/AddressesProvider.sol';

import { AaveV2Flashloan } from 'contracts/flashloan/AaveV2Flashloan.sol';
import { MakerFlashloan } from 'contracts/flashloan/MakerFlashloan.sol';
import { BalancerFlashloan } from 'contracts/flashloan/BalancerFlashloan.sol';

import { InchV5Connector } from 'contracts/connectors/InchV5.sol';
import { UniswapConnector } from 'contracts/connectors/Uniswap.sol';
import { AaveV2Connector } from 'contracts/connectors/AaveV2.sol';
import { AaveV3Connector } from 'contracts/connectors/AaveV3.sol';
import { CompoundV3Connector } from 'contracts/connectors/CompoundV3.sol';
import { CompoundV2Connector } from 'contracts/connectors/CompoundV2.sol';

contract Deployer is Test {
    Router router;
    Proxy accountProxy;
    Connectors connectors;

    InchV5Connector inchV5Connector;
    UniswapConnector uniswapConnector;
    AaveV2Connector aaveV2Connector;
    AaveV3Connector aaveV3Connector;
    CompoundV3Connector compoundV3Connector;
    CompoundV2Connector compoundV2Connector;

    AaveV2Flashloan aaveV2Flashloan;
    BalancerFlashloan balancerFlashloan;
    MakerFlashloan makerFlashloan;

    Configurator configurator;
    Account accountImpl;

    function setUp() public {
        string memory url = vm.rpcUrl('polygon');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        AddressesProvider addressesProvider = new AddressesProvider(address(this));
        addressesProvider.setAddress(bytes32('ACL_ADMIN'), msg.sender);

        ACLManager aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

        vm.prank(msg.sender);
        aclManager.addConnectorAdmin(msg.sender);

        vm.prank(msg.sender);
        aclManager.addRouterAdmin(msg.sender);

        addressesProvider.setAddress(bytes32('ACL_MANAGER'), address(aclManager));
        addressesProvider.setAddress(bytes32('CONNECTORS'), address(connectors));

        configurator = new Configurator();

        router = new Router(IAddressesProvider(address(addressesProvider)));
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
        router = Router(payable(addressesProvider.getRouter()));

        setUpConnectors();

        accountImpl = new Account(address(addressesProvider));
        accountProxy = new Proxy(address(addressesProvider));

        bytes32[] memory _namesA = new bytes32[](3);
        _namesA[0] = bytes32('ACCOUNT');
        _namesA[1] = bytes32('TREASURY');
        _namesA[2] = bytes32('ACCOUNT_PROXY');

        address[] memory _addresses = new address[](3);
        _addresses[0] = address(accountImpl);
        _addresses[1] = msg.sender;
        _addresses[2] = address(accountProxy);

        for (uint i = 0; i < _namesA.length; i++) {
            addressesProvider.setAddress(_namesA[i], _addresses[i]);
        }

        vm.prank(msg.sender);
        configurator.setFee(3);
    }

    function setUpConnectors() public {
        aaveV2Flashloan = new AaveV2Flashloan();
        balancerFlashloan = new BalancerFlashloan();
        makerFlashloan = new MakerFlashloan();

        inchV5Connector = new InchV5Connector();
        uniswapConnector = new UniswapConnector();
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
        compoundV3Connector = new CompoundV3Connector();
        compoundV2Connector = new CompoundV2Connector();

        string[] memory _names = new string[](9);
        _names[0] = aaveV2Connector.name();
        _names[1] = aaveV3Connector.name();
        _names[2] = compoundV3Connector.name();
        _names[3] = inchV5Connector.name();
        _names[4] = uniswapConnector.name();
        _names[5] = compoundV2Connector.name();
        _names[6] = aaveV2Flashloan.name();
        _names[7] = balancerFlashloan.name();
        _names[8] = makerFlashloan.name();

        address[] memory _connectors = new address[](9);
        _connectors[0] = address(aaveV2Connector);
        _connectors[1] = address(aaveV3Connector);
        _connectors[2] = address(compoundV3Connector);
        _connectors[3] = address(inchV5Connector);
        _connectors[4] = address(uniswapConnector);
        _connectors[5] = address(compoundV2Connector);
        _connectors[6] = address(aaveV2Flashloan);
        _connectors[7] = address(balancerFlashloan);
        _connectors[8] = address(makerFlashloan);

        vm.prank(msg.sender);
        configurator.addConnectors(_names, _connectors);
    }
}
