// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import { Errors } from './lib/Errors.sol';
import { PercentageMath } from './lib/PercentageMath.sol';

import { IReferral } from './interfaces/IReferral.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

contract Referral is IReferral {
    struct Tier {
        uint256 rebate;
        uint256 discountShare;
    }

    /* ============ Immutables ============ */

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /* ============ State Variables ============ */

    // Map of tier id and tier
    mapping(uint256 => Tier) private _tiers;

    // Map of users address and their tier (user address => user tier)
    mapping(address => uint256) public override referrerTier;

    // to override default value in tier
    mapping(address => uint256) public override referrerDiscountShare;

    // Map of trader address => referrer code
    mapping(address => bytes32) public override traderRefferalCodes;

    // Map of referrer code  => referrer address
    mapping(bytes32 => address) public override codesOfReferrer;

    /* ============ Events ============ */

    /* ============ Modifiers ============ */

    /**
     * @dev Only pool configurator can call functions marked by this modifier.
     */
    modifier onlyConfigurator() {
        require(ADDRESSES_PROVIDER.getConfigurator() == msg.sender, Errors.CALLER_NOT_CONFIGURATOR);
        _;
    }

    /**
     * @dev Only router can call functions marked by this modifier.
     */
    modifier onlyRouter() {
        require(ADDRESSES_PROVIDER.getRouter() == msg.sender, Errors.CALLER_NOT_ROUTER);
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _provider The address of the AddressesProvider contract
     */
    constructor(IAddressesProvider _provider) {
        require(address(_provider) != address(0), Errors.ADDRESS_IS_ZERO);
        ADDRESSES_PROVIDER = _provider;
    }

    /* ============ External Functions ============ */

    function registerReferrerCode(bytes32 _code) external override {
        require(_code != bytes32(0), 'invalid code');
        require(codesOfReferrer[_code] == address(0), 'code already exists');

        codesOfReferrer[_code] = msg.sender;
    }

    function setReferrerTier(address _referrer, uint256 _tier) external override onlyConfigurator {
        referrerTier[_referrer] = _tier;
    }

    function setReferrerDiscountShare(uint256 _discountShare) external override onlyConfigurator {
        referrerDiscountShare[msg.sender] = _discountShare;
    }

    function setReferrer(bytes32 _code, address _referrer) external override onlyConfigurator {
        require(_code != bytes32(0), 'invalid code');
        require(msg.sender == codesOfReferrer[_code], 'forbidden');

        codesOfReferrer[_code] = _referrer;
    }

    function setTraderCode(address _trader, bytes32 _code) external override onlyRouter {
        traderRefferalCodes[_trader] = _code;
    }

    function addTiers(
        uint256[] memory _ids,
        uint256[] memory _rebates,
        uint256[] memory _discountShares
    ) external override onlyConfigurator {
        uint256 length = _ids.length;

        require(length == _rebates.length, 'invalid rebates length');
        require(length == _discountShares.length, 'invalid shares length');

        for (uint i = 0; i < length; i++) {
            _addTier(_ids[i], _rebates[i], _discountShares[i]);
        }
    }

    function getTraderReferralInfo(address _trader) external view override returns (bytes32, address) {
        bytes32 code = traderRefferalCodes[_trader];
        address referrer;
        if (code != bytes32(0)) {
            referrer = codesOfReferrer[code];
        }
        return (code, referrer);
    }

    function _addTier(uint256 _id, uint256 _rebate, uint256 _discountShare) private {
        Tier memory tier = _tiers[_id];

        require(tier.discountShare == 0 && tier.rebate == 0, 'tier is exist');

        tier.rebate = _rebate;
        tier.discountShare = _discountShare;
        _tiers[_id] = tier;
    }
}
