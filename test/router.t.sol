// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "../src/dependencies/openzeppelin/contracts/ERC20.sol";
import { Clones } from "../src/dependencies/openzeppelin/upgradeability/Clones.sol";

import { DataTypes } from "../src/protocol/libraries/types/DataTypes.sol";

import { Router } from "../src/protocol/router/Router.sol";

import { UniswapConnector } from "../src/connectors/Uniswap.sol";

import { Connectors } from "../src/protocol/configuration/Connectors.sol";
import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

import { UniswapHelper } from "./uniswap.sol";

contract TestRouterSwap is Test, UniswapHelper {
    Router router;
    Connectors connectors;
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

        connectors = new Connectors();

        UniswapConnector swapConnector = new UniswapConnector();

        string[] memory _names = new string[](1);
        _names[0] = swapConnector.name();

        address[] memory _addresses = new address[](1);
        _addresses[0] = address(swapConnector);

        connectors.addConnectors(_names, _addresses);

        addressesProvider = new AddressesProvider();
        addressesProvider.setAddress(bytes32("CONNECTORS"), address(connectors));

        router = new Router(address(addressesProvider));
        addressesProvider.setRouterImpl(address(router));

        router = Router(addressesProvider.getRouter());
    }
}
