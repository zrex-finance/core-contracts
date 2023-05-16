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
            IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e),
            IPoolDataProvider(0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3),
            0
        )
    {}
}
