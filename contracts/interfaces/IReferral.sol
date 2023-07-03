// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IReferral {
    function referrerTier(address _referrer) external view returns (uint256);

    function referrerDiscountShare(address _referrer) external view returns (uint256);

    function traderRefferalCodes(address _trader) external view returns (bytes32);

    function codesOfReferrer(bytes32 _code) external view returns (address);

    function registerReferrerCode(bytes32 _code) external;

    function setReferrerTier(address _referrer, uint256 _tier) external;

    function setReferrerDiscountShare(uint256 _discountShare) external;

    function setReferrer(bytes32 _code, address _referrer) external;

    function setTraderCode(address _trader, bytes32 _code) external;

    function addTiers(uint256[] memory _ids, uint256[] memory _rebates, uint256[] memory _discountShares) external;

    function getTraderReferralInfo(address _trader) external view returns (bytes32, address);
}
