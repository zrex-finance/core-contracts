// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { DataTypes } from "../src/protocol/libraries/types/DataTypes.sol";
import { IAddressesProvider } from "../src/interfaces/IAddressesProvider.sol";

import { Proxy } from "../src/protocol/router/Proxy.sol";
import { Router } from "../src/protocol/router/Router.sol";
import { Account } from "../src/protocol/router/Account.sol";

import { FlashResolver } from "../src/flashloans/FlashResolver.sol";
import { FlashAggregator } from "../src/flashloans/FlashAggregator.sol";

import { Connectors } from "../src/protocol/configuration/Connectors.sol";
import { Implementations } from "../src/protocol/configuration/Implementations.sol";
import { AddressesProvider } from "../src/protocol/configuration/AddressesProvider.sol";

import { InchV5Connector } from "../src/connectors/InchV5.sol";
import { UniswapConnector } from "../src/connectors/Uniswap.sol";
import { EulerConnector } from "../src/connectors/Euler.sol";
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
    EulerConnector eulerConnector;
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

        accountImpl = new Account();
        Implementations implementations = new Implementations();

        implementations.setDefaultImplementation(address(accountImpl));

        accountProxy = new Proxy(address(implementations));

        uint256 fee = 3;

        router = new Router(fee, address(addressesProvider));

        bytes32[] memory _namesA = new bytes32[](6);
        _namesA[0] = bytes32("ROUTER");
        _namesA[1] = bytes32("TREASURY");
        _namesA[2] = bytes32("CONNECTORS");
        _namesA[3] = bytes32("ACCOUNT_PROXY");
        _namesA[4] = bytes32("IMPLEMENTATIONS");
        _namesA[5] = bytes32("FLASHLOAN_AGGREGATOR");

        address[] memory _addresses = new address[](6);
        _addresses[0] = address(router);
        _addresses[1] = msg.sender;
        _addresses[2] = address(connectors);
        _addresses[3] = address(accountProxy);
        _addresses[4] = address(implementations);
        _addresses[5] = address(flashloanAggregator);

        for (uint i = 0; i < _namesA.length; i++) {
            addressesProvider.setAddress(_namesA[i], _addresses[i]);
        }
    }

    function setUpConnectors() public {
        connectors = new Connectors();

        inchV5Connector = new InchV5Connector();
        uniswapConnector = new UniswapConnector();
        eulerConnector = new EulerConnector();
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
        compoundV3Connector = new CompoundV3Connector();
        compoundV2Connector = new CompoundV2Connector();

        string[] memory _names = new string[](7);
        _names[0] = eulerConnector.name();
        _names[1] = aaveV2Connector.name();
        _names[2] = aaveV3Connector.name();
        _names[3] = compoundV3Connector.name();
        _names[4] = inchV5Connector.name();
        _names[5] = uniswapConnector.name();
        _names[6] = compoundV2Connector.name();

        address[] memory _connectors = new address[](7);
        _connectors[0] = address(eulerConnector);
        _connectors[1] = address(aaveV2Connector);
        _connectors[2] = address(aaveV3Connector);
        _connectors[3] = address(compoundV3Connector);
        _connectors[4] = address(inchV5Connector);
        _connectors[5] = address(uniswapConnector);
        _connectors[6] = address(compoundV2Connector);

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
