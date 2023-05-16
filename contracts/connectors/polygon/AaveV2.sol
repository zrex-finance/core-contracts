// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IProtocolDataProvider } from '../../interfaces/external/aave-v2/IProtocolDataProvider.sol';
import { ILendingPoolAddressesProvider } from '../../interfaces/external/aave-v2/ILendingPoolAddressesProvider.sol';

import { AaveV2BaseConnector } from '../base/AaveV2.sol';

contract AaveV2Connector is AaveV2BaseConnector {
    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     */
    constructor()
        AaveV2BaseConnector(
            ILendingPoolAddressesProvider(0xd05e3E715d945B59290df0ae8eF85c1BdB684744),
            IProtocolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d),
            0
        )
    {}
}
