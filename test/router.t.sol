// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "../src/dependencies/openzeppelin/contracts/ERC20.sol";
import { Clones } from "../src/dependencies/openzeppelin/upgradeability/Clones.sol";

import { DataTypes } from "../src/protocol/libraries/types/DataTypes.sol";
import { IAddressesProvider } from "../src/interfaces/IAddressesProvider.sol";

import { Router } from "../src/protocol/router/Router.sol";

import { UniswapConnector } from "../src/connectors/Uniswap.sol";

import { Connectors } from "../src/protocol/configuration/Connectors.sol";
import { ACLManager } from "../src/protocol/configuration/ACLManager.sol";
import { Configurator } from "../src/protocol/configuration/Configurator.sol";
import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

import { UniswapHelper } from "./uniswap.sol";

contract TestRouterSwap is Test, UniswapHelper {
    Router router;
    Connectors connectors;
    Configurator configurator;
    ACLManager aclManager;
    AddressesProvider addressesProvider;

    address testAddress;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    // Main identifiers
    function test_swapDaiToWeth() public {
        uint256 amount = 1000 ether;

        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(this), amount);

        ERC20(daiC).approve(address(router), amount);

        bytes memory swapdata = getSwapData(daiC, wethC, address(this), amount);
        router.swap(DataTypes.SwapParams(daiC, wethC, amount, "UniswapAuto", swapdata));

        assertTrue(ERC20(wethC).balanceOf(address(this)) > 0);
    }

    function test_swapDaiToWeth_Revert() public {
        uint256 amount = 1000 ether;

        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(this), amount);

        ERC20(daiC).approve(address(router), amount);

        bytes memory _data = getMulticalSwapData(daiC, wethC, address(this), amount);
        bytes memory swapData = abi.encodeWithSelector(
            UniswapConnector.swap.selector,
            wethC,
            daiC,
            amount,
            abi.encode(uint(123), _data)
        );

        vm.expectRevert(bytes(""));
        router.swap(DataTypes.SwapParams(daiC, wethC, amount, "UniswapAuto", swapData));
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl("mainnet");
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        addressesProvider = new AddressesProvider();
        addressesProvider.setAddress(bytes32("ACL_ADMIN"), address(this));

        aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

        aclManager.addConnectorAdmin(address(this));
        aclManager.addRouterAdmin(address(this));

        addressesProvider.setAddress(bytes32("ACL_MANAGER"), address(aclManager));
        addressesProvider.setAddress(bytes32("CONNECTORS"), address(connectors));

        configurator = new Configurator();

        router = new Router(address(addressesProvider));
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
        router = Router(addressesProvider.getRouter());

        UniswapConnector swapConnector = new UniswapConnector();

        string[] memory _names = new string[](1);
        _names[0] = swapConnector.name();

        address[] memory _addresses = new address[](1);
        _addresses[0] = address(swapConnector);

        configurator.addConnectors(_names, _addresses);
    }
}
