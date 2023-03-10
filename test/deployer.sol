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

import { Mapping } from "../src/protocol/configuration/Mapping.sol";
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
    Mapping mappingC;

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

        address[] memory _ctokens = new address[](19);
        _ctokens[0] = 0xe65cdB6479BaC1e22340E4E755fAE7E509EcD06c;
        _ctokens[1] = 0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E;
        _ctokens[2] = 0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4;
        _ctokens[3] = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
        _ctokens[4] = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
        _ctokens[5] = 0x7713DD9Ca933848F6819F38B8352D9A15EA73F67;
        _ctokens[6] = 0xFAce851a4921ce59e912d19329929CE6da6EB0c7;
        _ctokens[7] = 0x95b4eF2869eBD94BEb4eEE400a99824BF5DC325b;
        _ctokens[8] = 0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1;
        _ctokens[9] = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
        _ctokens[10] = 0x4B0181102A0112A2ef11AbEE5563bb4a3176c9d7;
        _ctokens[11] = 0x12392F67bdf24faE0AF363c24aC620a2f67DAd86;
        _ctokens[12] = 0x35A18000230DA775CAc24873d00Ff85BccdeD550;
        _ctokens[13] = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;
        _ctokens[14] = 0x041171993284df560249B57358F931D9eB7b925D;
        _ctokens[15] = 0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9;
        _ctokens[16] = 0xccF4429DB6322D5C611ee964527D42E5d685DD6a;
        _ctokens[17] = 0x80a2AE356fc9ef4305676f7a3E2Ed04e12C33946;
        _ctokens[18] = 0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407;

        address[] memory _tokens = new address[](_ctokens.length);

        for (uint i = 0; i < _ctokens.length; i++) {
            // ceth
            if (_ctokens[i] == 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5) {
                _tokens[i] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
            } else {
                address _token = ICToken(_ctokens[i]).underlying();
                _tokens[i] = _token;
            }
        }

        mappingC = new Mapping(_tokens, _ctokens);

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
