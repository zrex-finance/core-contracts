// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FlashloanAggregatorInterface, IAaveProtocolDataProvider, IERC3156FlashLender} from "./interfaces.sol";

contract Variables {
    address public constant chainToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant aaveLendingAddr = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

    IERC3156FlashLender internal constant makerLending = IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
    
    address public constant aaveProtocolDataProviderAddr = 0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d;
    IAaveProtocolDataProvider public constant aaveProtocolDataProvider = IAaveProtocolDataProvider(aaveProtocolDataProviderAddr);

    address public constant balancerLendingAddr = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address public constant daiToken = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint256 public constant daiBorrowAmount = 500000000000000000000000000;

    address public constant cEthToken = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;

    FlashloanAggregatorInterface internal flashloanAggregator;

    address internal constant randomAddr_ = 0xa9061100d29C3C562a2e2421eb035741C1b42137;
}
