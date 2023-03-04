// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SharedStructs } from "../src/lib/SharedStructs.sol";

import { PositionRouter } from "../src/positions/PositionRouter.sol";
import { FlashReceiver } from "../src/positions/FlashReceiver.sol";

import { SwapRouter } from "../src/swap/SwapRouter.sol";
import { FlashResolver } from "../src/flashloans/FlashResolver.sol";
import { FlashAggregator } from "../src/flashloans/FlashAggregator.sol";

import { Connectors } from "../src/connectors/Connectors.sol";
import { EulerConnector } from "../src/connectors/Euler.sol";
import { AaveV2Connector } from "../src/connectors/AaveV2.sol";
import { AaveV3Connector } from "../src/connectors/AaveV3.sol";
import { CompoundV3Connector } from "../src/connectors/CompoundV3.sol";

import { Proxy } from "../src/accounts/Proxy.sol";
import { Regestry } from "../src/accounts/Regestry.sol";
import { Implementation } from "../src/accounts/Implementation.sol";
import { Implementations } from "../src/accounts/Implementations.sol";

contract Deployer is Test {
    FlashResolver flashResolver;

    Regestry regestry;
    PositionRouter router;

    Proxy accountProxy;

    Connectors connectors;
    SwapRouter swapRouter;
    EulerConnector eulerConnector;
    AaveV2Connector aaveV2Connector;
    AaveV3Connector aaveV3Connector;
    CompoundV3Connector compoundV3Connector;

    Implementation implementation;

    function setUp() public {
        string memory url = vm.rpcUrl("mainnet");
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);
        
        connectors = new Connectors();

        swapRouter = new SwapRouter();
        eulerConnector = new EulerConnector();
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
        compoundV3Connector = new CompoundV3Connector();

        string[] memory _names = new string[](5);
        _names[0] = eulerConnector.name();
        _names[1] = aaveV2Connector.name();
        _names[2] = aaveV3Connector.name();
        _names[3] = compoundV3Connector.name();
        _names[4] = swapRouter.name();

        address[] memory _connectors = new address[](5);
        _connectors[0] = address(eulerConnector);
        _connectors[1] = address(aaveV2Connector);
        _connectors[2] = address(aaveV3Connector);
        _connectors[3] = address(compoundV3Connector);
        _connectors[4] = address(swapRouter);

        connectors.addConnectors(_names, _connectors);
 
        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));

        uint256 fee = 3;
        address treasary = msg.sender;

        router = new PositionRouter(address(flashloanAggregator), address(connectors), fee, treasary);

        implementation = new Implementation();
        Implementations implementations = new Implementations();

        implementations.setDefaultImplementation(address(implementation));

        accountProxy = new Proxy(address(implementations));
        regestry = new Regestry(address(accountProxy), address(router));
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