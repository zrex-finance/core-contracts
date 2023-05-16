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
            ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5),
            IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d),
            0
        )
    {}
}
