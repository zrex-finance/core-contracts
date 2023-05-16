// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IPoolDataProvider } from '../../interfaces/external/aave-v3/IPoolDataProvider.sol';
import { IPoolAddressesProvider } from '../../interfaces/external/aave-v3/IPoolAddressesProvider.sol';

import { AaveV3BaseConnector } from '../base/AaveV3.sol';

contract AaveV3Connector is AaveV3BaseConnector {
    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     */
    constructor()
        AaveV3BaseConnector(
            IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb),
            IPoolDataProvider(0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654),
            0
        )
    {}
}
