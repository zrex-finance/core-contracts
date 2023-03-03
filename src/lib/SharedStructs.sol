// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library SharedStructs {
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 sizeDelta;
        uint256 collateralAmount;
        uint256 borrowAmount;
    }
}