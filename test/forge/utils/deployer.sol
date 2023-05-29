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
import { UniswapFlashloan } from 'contracts/flashloan/UniswapFlashloan.sol';

import { InchV5Connector } from 'contracts/connectors/InchV5.sol';
import { UniswapConnector } from 'contracts/connectors/Uniswap.sol';
import { CompoundV3Connector } from 'contracts/connectors/CompoundV3.sol';
import { VenusConnector } from 'contracts/connectors/bsc/Venus.sol';
import { AaveV2Connector } from 'contracts/connectors/mainnet/AaveV2.sol';
import { AaveV3Connector } from 'contracts/connectors/mainnet/AaveV3.sol';
import { CompoundV2Connector } from 'contracts/connectors/mainnet/CompoundV2.sol';

contract Deployer is Test {
    Router public router;
    Proxy public accountProxy;
    Connectors public connectors;

    InchV5Connector public inchV5Connector;
    UniswapConnector public uniswapConnector;
    AaveV2Connector public aaveV2Connector;
    AaveV3Connector public aaveV3Connector;
    CompoundV3Connector public compoundV3Connector;
    CompoundV2Connector public compoundV2Connector;
    VenusConnector public venusConnector;

    AaveV2Flashloan public aaveV2Flashloan;
    BalancerFlashloan public balancerFlashloan;
    MakerFlashloan public makerFlashloan;
    UniswapFlashloan public uniswapFlashloan;

    Configurator public configurator;
    Account public accountImpl;

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
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
        aaveV2Flashloan = new AaveV2Flashloan(
            0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,
            0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d
        );
        balancerFlashloan = new BalancerFlashloan(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        makerFlashloan = new MakerFlashloan(
            0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853,
            0x6B175474E89094C44Da98b954EedeAC495271d0F
        );

        venusConnector = new VenusConnector();
        uniswapFlashloan = new UniswapFlashloan(
            0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7,
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        );
        inchV5Connector = new InchV5Connector();
        uniswapConnector = new UniswapConnector();
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
        compoundV3Connector = new CompoundV3Connector();
        compoundV2Connector = new CompoundV2Connector();

        string[] memory _names = new string[](11);
        _names[0] = aaveV2Connector.NAME();
        _names[1] = aaveV3Connector.NAME();
        _names[2] = compoundV3Connector.NAME();
        _names[3] = inchV5Connector.NAME();
        _names[4] = uniswapConnector.NAME();
        _names[5] = compoundV2Connector.NAME();
        _names[6] = aaveV2Flashloan.NAME();
        _names[7] = balancerFlashloan.NAME();
        _names[8] = makerFlashloan.NAME();
        _names[9] = uniswapFlashloan.NAME();
        _names[10] = venusConnector.NAME();

        address[] memory _connectors = new address[](11);
        _connectors[0] = address(aaveV2Connector);
        _connectors[1] = address(aaveV3Connector);
        _connectors[2] = address(compoundV3Connector);
        _connectors[3] = address(inchV5Connector);
        _connectors[4] = address(uniswapConnector);
        _connectors[5] = address(compoundV2Connector);
        _connectors[6] = address(aaveV2Flashloan);
        _connectors[7] = address(balancerFlashloan);
        _connectors[8] = address(makerFlashloan);
        _connectors[9] = address(uniswapFlashloan);
        _connectors[10] = address(venusConnector);

        vm.prank(msg.sender);
        configurator.addConnectors(_names, _connectors);
    }
}
