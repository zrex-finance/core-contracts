// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import { Errors } from './lib/Errors.sol';

import { IOracle } from './interfaces/IOracle.sol';
import { IACLManager } from './interfaces/IACLManager.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';
import { AggregatorInterface } from './interfaces/external/chainlink/AggregatorInterface.sol';

/**
 * @title FlashFlowOracle
 * @author FlashFlow
 * @notice Contract to get asset prices, manage price sources and update the fallback oracle
 * - Use of Chainlink Aggregators as first source of price
 * - If the returned price by a Chainlink aggregator is <= 0, the call is forwarded to a fallback oracle
 */
contract Oracle is IOracle {
    /* ============ Immutables ============ */

    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /* ============ State Variables ============ */

    // Map of asset price sources (asset => priceSource)
    mapping(address => AggregatorInterface) private assetsSources;

    /* ============ Events ============ */

    /**
     * @dev Emitted after the price source of an asset is updated
     * @param asset The address of the asset
     * @param source The price source of the asset
     */
    event AssetSourceUpdated(address indexed asset, address indexed source);

    /* ============ Modifiers ============ */

    /**
     * @dev Only asset listing or pool admin can call functions marked by this modifier.
     */
    modifier onlyAssetListingOrPoolAdmins() {
        _onlyAssetListingOrRouterAdmins();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor
     * @param provider The address of the new PoolAddressesProvider
     * @param assets The addresses of the assets
     * @param sources The address of the source of each asset
     */
    constructor(IAddressesProvider provider, address[] memory assets, address[] memory sources) {
        ADDRESSES_PROVIDER = provider;
        _setAssetsSources(assets, sources);
    }

    /* ============ External Functions ============ */

    /**
     * @notice Sets or replaces price sources of assets
     * @param assets The addresses of the assets
     * @param sources The addresses of the price sources
     */
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external override onlyAssetListingOrPoolAdmins {
        _setAssetsSources(assets, sources);
    }

    /**
     * @notice Returns a list of prices from a list of assets addresses
     * @param assets The list of assets addresses
     * @return The prices of the given assets
     */
    function getAssetsPrices(address[] calldata assets) external view override returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            prices[i] = getAssetPrice(assets[i]);
        }
        return prices;
    }

    /**
     * @notice Returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return The address of the source
     */
    function getSourceOfAsset(address asset) external view override returns (address) {
        return address(assetsSources[asset]);
    }

    /* ============ Public Functions ============ */

    /**
     * @notice Returns the asset price in the base currency
     * @param asset The address of the asset
     * @return The price of the asset
     */
    function getAssetPrice(address asset) public view override returns (uint256) {
        AggregatorInterface source = assetsSources[asset];
        require(address(source) == address(0), Errors.ADDRESS_IS_ZERO);

        int256 price = source.latestAnswer();
        if (price > 0) {
            return uint256(price);
        } else {
            return 0;
        }
    }

    /* ============ Private Functions ============ */

    /**
     * @notice Internal function to set the sources for each asset
     * @param assets The addresses of the assets
     * @param sources The address of the source of each asset
     */
    function _setAssetsSources(address[] memory assets, address[] memory sources) internal {
        require(assets.length == sources.length, Errors.INCONSISTENT_PARAMS_LENGTH);
        for (uint256 i = 0; i < assets.length; i++) {
            assetsSources[assets[i]] = AggregatorInterface(sources[i]);
            emit AssetSourceUpdated(assets[i], sources[i]);
        }
    }

    function _onlyAssetListingOrRouterAdmins() internal view {
        IACLManager aclManager = IACLManager(ADDRESSES_PROVIDER.getACLManager());
        require(
            aclManager.isAssetListingAdmin(msg.sender) || aclManager.isRouterAdmin(msg.sender),
            Errors.CALLER_NOT_ASSET_LISTING_OR_ROUTER_ADMIN
        );
    }
}
