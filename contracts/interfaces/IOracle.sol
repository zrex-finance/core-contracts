// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import { IAddressesProvider } from './IAddressesProvider.sol';

interface IOracle {
    function ADDRESSES_PROVIDER() external view returns (IAddressesProvider);

    function setAssetSources(address[] calldata assets, address[] calldata sources) external;

    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);

    function getAssetPrice(address asset) external view returns (uint256);

    function getSourceOfAsset(address asset) external view returns (address);
}
