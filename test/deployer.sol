// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "../src/dependencies/openzeppelin/contracts/ERC20.sol";

import { DataTypes } from "../src/protocol/libraries/types/DataTypes.sol";
import { IAddressesProvider } from "../src/interfaces/IAddressesProvider.sol";

import { Proxy } from "../src/protocol/account/Proxy.sol";
import { Account } from "../src/protocol/account/Account.sol";

import { Router } from "../src/protocol/router/Router.sol";
import { RouterConfigurator } from "../src/protocol/router/RouterConfigurator.sol";

import { FlashResolver } from "../src/flashloans/FlashResolver.sol";
import { FlashAggregator } from "../src/flashloans/FlashAggregator.sol";

import { Connectors } from "../src/protocol/configuration/Connectors.sol";
import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

import { InchV5Connector } from "../src/connectors/InchV5.sol";
import { UniswapConnector } from "../src/connectors/Uniswap.sol";
import { AaveV2Connector } from "../src/connectors/AaveV2.sol";
import { AaveV3Connector } from "../src/connectors/AaveV3.sol";
import { CompoundV3Connector } from "../src/connectors/CompoundV3.sol";
import { CompoundV2Connector } from "../src/connectors/CompoundV2.sol";

interface ICToken {
    function isCToken() external view returns (bool);

    function underlying() external view returns (address);
}

contract Deployer is Test {
    FlashResolver flashResolver;

    Router router;
    Proxy accountProxy;
    Connectors connectors;

    InchV5Connector inchV5Connector;
    UniswapConnector uniswapConnector;
    AaveV2Connector aaveV2Connector;
    AaveV3Connector aaveV3Connector;
    CompoundV3Connector compoundV3Connector;
    CompoundV2Connector compoundV2Connector;

    Account accountImpl;

    struct SwapParams {
        address fromToken;
        uint256 amount;
        string targetName;
        bytes data;
    }

    function setUp() public {
        string memory url = vm.rpcUrl("mainnet");
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        setUpConnectors();

        AddressesProvider addressesProvider = new AddressesProvider();

        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));

        RouterConfigurator routerConfigurator = new RouterConfigurator();

        accountImpl = new Account(address(addressesProvider));
        accountProxy = new Proxy(address(addressesProvider));
        router = new Router(address(addressesProvider));

        bytes32[] memory _namesA = new bytes32[](5);
        _namesA[0] = bytes32("ACCOUNT");
        _namesA[1] = bytes32("TREASURY");
        _namesA[2] = bytes32("CONNECTORS");
        _namesA[3] = bytes32("ACCOUNT_PROXY");
        _namesA[4] = bytes32("FLASHLOAN_AGGREGATOR");

        address[] memory _addresses = new address[](5);
        _addresses[0] = address(accountImpl);
        _addresses[1] = msg.sender;
        _addresses[2] = address(connectors);
        _addresses[3] = address(accountProxy);
        _addresses[4] = address(flashloanAggregator);

        for (uint i = 0; i < _namesA.length; i++) {
            addressesProvider.setAddress(_namesA[i], _addresses[i]);
        }

        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setRouterConfiguratorImpl(address(routerConfigurator));

        RouterConfigurator(addressesProvider.getRouterConfigurator()).setFee(3);

        router = Router(addressesProvider.getRouter());
    }

    function setUpConnectors() public {
        connectors = new Connectors();

        inchV5Connector = new InchV5Connector();
        uniswapConnector = new UniswapConnector();
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
        compoundV3Connector = new CompoundV3Connector();
        compoundV2Connector = new CompoundV2Connector();

        string[] memory _names = new string[](6);
        _names[0] = aaveV2Connector.name();
        _names[1] = aaveV3Connector.name();
        _names[2] = compoundV3Connector.name();
        _names[3] = inchV5Connector.name();
        _names[4] = uniswapConnector.name();
        _names[5] = compoundV2Connector.name();

        address[] memory _connectors = new address[](6);
        _connectors[0] = address(aaveV2Connector);
        _connectors[1] = address(aaveV3Connector);
        _connectors[2] = address(compoundV3Connector);
        _connectors[3] = address(inchV5Connector);
        _connectors[4] = address(uniswapConnector);
        _connectors[5] = address(compoundV2Connector);

        connectors.addConnectors(_names, _connectors);
    }
}

contract HelperContract is Test {
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;
    address usdcWhale = 0x5414d89a8bF7E99d732BC52f3e6A3Ef461c0C078;

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).transfer(msg.sender, amt);
    }
}
