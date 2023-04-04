// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library DataTypes {
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 leverage;
        uint256 collateralAmount;
        uint256 borrowAmount;
    }
}
