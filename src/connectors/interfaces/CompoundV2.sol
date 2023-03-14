// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ICToken {
    function mint(uint mintAmount) external returns (uint);

    function underlying() external returns (address);

    function redeem(uint redeemTokens) external returns (uint);

    function borrow(uint borrowAmount) external returns (uint);

    function repayBorrow(uint repayAmount) external returns (uint);

    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint); // For ERC20

    function liquidateBorrow(address borrower, uint repayAmount, address cTokenCollateral) external returns (uint);

    function borrowBalanceCurrent(address account) external returns (uint);

    function balanceOfUnderlying(address account) external returns (uint256);

    function redeemUnderlying(uint redeemAmount) external returns (uint);

    function exchangeRateCurrent() external returns (uint);

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);

    function exitMarket(address cTokenAddress) external returns (uint);

    function getAssetsIn(address account) external view returns (address[] memory);

    function getAccountLiquidity(address account) external view returns (uint, uint, uint);

    function claimComp(address) external;
}

interface ICompoundMapping {
    function cTokenMapping(address _token) external view returns (address);

    function getMapping(address _token) external view returns (address, address);
}
