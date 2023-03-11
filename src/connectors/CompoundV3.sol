// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { IComet } from "./interfaces/CompoundV3.sol";

contract CompoundV3Connector {
    using UniversalERC20 for IERC20;

    struct BorrowWithdrawParams {
        address market;
        address token;
        address from;
        address to;
        uint256 amount;
    }

    struct BuyCollateralData {
        address market;
        address sellToken;
        address buyAsset;
        uint256 unitamount;
        uint256 baseSellamount;
    }

    enum Action {
        REPAY,
        DEPOSIT
    }

    string public constant name = "CompoundV3";

    function deposit(address market, address token, uint256 amount) public payable {
        require(market != address(0) && token != address(0), "invalid market/token address");

        IERC20 tokenC = IERC20(token);

        if (token == getBaseToken(market)) {
            require(IComet(market).borrowBalanceOf(address(this)) == 0, "debt not repaid");
        }

        amount = amount == type(uint).max ? tokenC.balanceOf(address(this)) : amount;

        tokenC.universalApprove(market, amount);

        IComet(market).supply(token, amount);
    }

    function borrowBalanceOf(address _market, address _recipient) public view returns (uint256) {
        return IComet(_market).borrowBalanceOf(_recipient);
    }

    function collateralBalanceOf(address _market, address _recipient, address _token) public view returns (uint256) {
        return IComet(_market).collateralBalanceOf(_recipient, _token);
    }

    function withdraw(address market, address token, uint256 amount) public payable {
        require(market != address(0) && token != address(0), "invalid market/token address");

        uint256 initialBalance = _getAccountSupplyBalanceOfAsset(address(this), market, token);

        if (token == getBaseToken(market)) {
            if (amount == type(uint).max) {
                amount = initialBalance;
            } else {
                //if there are supplies, ensure withdrawn amount
                // is not greater than supplied i.e can't borrow using withdraw.
                require(amount <= initialBalance, "withdraw-amount-greater-than-supplies");
            }

            //if borrow balance > 0, there are no supplies so no withdraw, borrow instead.
            require(IComet(market).borrowBalanceOf(address(this)) == 0, "withdraw-disabled-for-zero-supplies");
        } else {
            amount = amount == type(uint).max ? initialBalance : amount;
        }

        IComet(market).withdraw(token, amount);
    }

    function borrow(address market, address token, uint256 amount) external payable {
        require(market != address(0), "invalid market address");
        require(token == getBaseToken(market), "invalid token");
        require(IComet(market).balanceOf(address(this)) == 0, "borrow-disabled-when-supplied-base");

        IComet(market).withdraw(token, amount);
    }

    function payback(address market, address token, uint256 amount) external payable {
        require(market != address(0) && token != address(0), "invalid market/token address");

        require(token == getBaseToken(market), "invalid-token");

        IERC20 tokenC = IERC20(token);

        uint256 initialBalance = IComet(market).borrowBalanceOf(address(this));

        if (amount == type(uint).max) {
            amount = initialBalance;
        } else {
            require(amount <= initialBalance, "payback-amount-greater-than-borrows");
        }

        //if supply balance > 0, there are no borrowing so no repay, supply instead.
        require(IComet(market).balanceOf(address(this)) == 0, "cannot-repay-when-supplied");

        tokenC.universalApprove(market, amount);

        IComet(market).supply(token, amount);
    }

    function getBaseToken(address market) internal view returns (address baseToken) {
        baseToken = IComet(market).baseToken();
    }

    function _borrow(BorrowWithdrawParams memory params) internal returns (uint256 amount) {
        amount = params.amount;

        require(
            params.market != address(0) && params.token != address(0) && params.to != address(0),
            "invalid market/token/to address"
        );

        params.from = params.from == address(0) ? address(this) : params.from;

        require(IComet(params.market).balanceOf(params.from) == 0, "borrow-disabled-when-supplied-base");

        uint256 initialBalance = IComet(params.market).borrowBalanceOf(params.from);

        IComet(params.market).withdrawFrom(params.from, params.to, params.token, amount);

        uint256 finalBalance = IComet(params.market).borrowBalanceOf(params.from);
        amount = finalBalance - initialBalance;
    }

    function _withdraw(BorrowWithdrawParams memory params) internal returns (uint256 amount) {
        amount = params.amount;

        require(
            params.market != address(0) && params.token != address(0) && params.to != address(0),
            "invalid market/token/to address"
        );

        params.from = params.from == address(0) ? address(this) : params.from;

        uint256 initialBalance = _getAccountSupplyBalanceOfAsset(params.from, params.market, params.token);

        if (params.token == getBaseToken(params.market)) {
            //if there are supplies, ensure withdrawn amount is not greater
            // than supplied i.e can't borrow using withdraw.
            if (amount == type(uint).max) {
                amount = initialBalance;
            } else {
                require(amount <= initialBalance, "withdraw-amount-greater-than-supplies");
            }

            //if borrow balance > 0, there are no supplies so no withdraw, borrow instead.
            require(IComet(params.market).borrowBalanceOf(params.from) == 0, "withdraw-disabled-for-zero-supplies");
        } else {
            amount = amount == type(uint).max ? initialBalance : amount;
        }

        IComet(params.market).withdrawFrom(params.from, params.to, params.token, amount);

        uint256 finalBalance = _getAccountSupplyBalanceOfAsset(params.from, params.market, params.token);
        amount = initialBalance - finalBalance;
    }

    function _getAccountSupplyBalanceOfAsset(
        address account,
        address market,
        address asset
    ) internal returns (uint256 balance) {
        if (asset == getBaseToken(market)) {
            //balance in base
            balance = IComet(market).balanceOf(account);
        } else {
            //balance in asset denomination
            balance = uint256(IComet(market).userCollateral(account, asset).balance);
        }
    }
}
