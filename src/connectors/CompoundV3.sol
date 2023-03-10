// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../lib/UniversalERC20.sol";

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

    function depositOnBehalf(address market, address token, address to, uint256 amount) public payable {
        require(market != address(0) && token != address(0) && to != address(0), "invalid market/token/to address");

        IERC20 tokenC = IERC20(token);

        if (token == getBaseToken(market)) {
            require(IComet(market).borrowBalanceOf(to) == 0, "to address position debt not repaid");
        }

        amount = amount == type(uint).max ? tokenC.balanceOf(address(this)) : amount;

        tokenC.universalApprove(market, amount);

        IComet(market).supplyTo(to, token, amount);
    }

    function depositFromUsingManager(
        address market,
        address token,
        address from,
        address to,
        uint256 amount
    ) public payable {
        require(market != address(0) && token != address(0) && to != address(0), "invalid market/token/to address");
        require(from != address(this), "from-cannot-be-address(this)-use-depositOnBehalf");

        if (token == getBaseToken(market)) {
            require(IComet(market).borrowBalanceOf(to) == 0, "to-address-position-debt-not-repaid");
        }

        amount = _calculateFromAmount(market, token, from, amount, Action.DEPOSIT);

        IComet(market).supplyFrom(from, to, token, amount);
    }

    function withdraw(address market, address token, uint256 amount) public payable {
        require(market != address(0) && token != address(0), "invalid market/token address");

        uint256 initialBalance = _getAccountSupplyBalanceOfAsset(address(this), market, token);

        if (token == getBaseToken(market)) {
            if (amount == type(uint).max) {
                amount = initialBalance;
            } else {
                //if there are supplies, ensure withdrawn amount is not greater than supplied i.e can't borrow using withdraw.
                require(amount <= initialBalance, "withdraw-amount-greater-than-supplies");
            }

            //if borrow balance > 0, there are no supplies so no withdraw, borrow instead.
            require(IComet(market).borrowBalanceOf(address(this)) == 0, "withdraw-disabled-for-zero-supplies");
        } else {
            amount = amount == type(uint).max ? initialBalance : amount;
        }

        IComet(market).withdraw(token, amount);
    }

    function withdrawTo(address market, address token, address to, uint256 amount) public payable {
        _withdraw(BorrowWithdrawParams({ market: market, token: token, from: address(this), to: to, amount: amount }));
    }

    function withdrawOnBehalf(address market, address token, address from, uint256 amount) public payable {
        _withdraw(
            BorrowWithdrawParams({ market: market, token: token, from: from, to: address(this), amount: amount })
        );
    }

    function withdrawOnBehalfAndTransfer(
        address market,
        address token,
        address from,
        address to,
        uint256 amount
    ) public payable {
        _withdraw(BorrowWithdrawParams({ market: market, token: token, from: from, to: to, amount: amount }));
    }

    function borrow(address market, address token, uint256 amount) external payable {
        require(market != address(0), "invalid market address");
        require(token == getBaseToken(market), "invalid token");
        require(IComet(market).balanceOf(address(this)) == 0, "borrow-disabled-when-supplied-base");

        IComet(market).withdraw(token, amount);
    }

    function borrowTo(address market, address token, address to, uint256 amount) external payable {
        require(token == getBaseToken(market), "invalid-token");
        _borrow(BorrowWithdrawParams({ market: market, token: token, from: address(this), to: to, amount: amount }));
    }

    function borrowOnBehalf(address market, address token, address from, uint256 amount) external payable {
        require(token == getBaseToken(market), "invalid-token");
        _borrow(BorrowWithdrawParams({ market: market, token: token, from: from, to: address(this), amount: amount }));
    }

    function borrowOnBehalfAndTransfer(
        address market,
        address token,
        address from,
        address to,
        uint256 amount
    ) external payable {
        require(token == getBaseToken(market), "invalid-token");
        _borrow(BorrowWithdrawParams({ market: market, token: token, from: from, to: to, amount: amount }));
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

    function paybackOnBehalf(address market, address token, address to, uint256 amount) external payable {
        require(market != address(0) && token != address(0) && to != address(0), "invalid market/token/to address");

        require(token == getBaseToken(market), "invalid-token");

        IERC20 tokenC = IERC20(token);

        uint256 initialBalance = IComet(market).borrowBalanceOf(to);

        if (amount == type(uint).max) {
            amount = initialBalance;
        } else {
            require(amount <= initialBalance, "payback-amount-greater-than-borrows");
        }

        //if supply balance > 0, there are no borrowing so no repay, supply instead.
        require(IComet(market).balanceOf(to) == 0, "cannot-repay-when-supplied");

        tokenC.universalApprove(market, amount);

        IComet(market).supplyTo(to, token, amount);
    }

    function paybackFromUsingManager(
        address market,
        address token,
        address from,
        address to,
        uint256 amount
    ) external payable {
        require(market != address(0) && token != address(0) && to != address(0), "invalid market/token/to address");
        require(from != address(this), "from-cannot-be-address(this)-use-paybackOnBehalf");

        require(token == getBaseToken(market), "invalid-token");

        if (amount == type(uint).max) {
            amount = _calculateFromAmount(market, token, from, amount, Action.REPAY);
        } else {
            uint256 initialBalance = IComet(market).borrowBalanceOf(to);
            require(amount <= initialBalance, "payback-amount-greater-than-borrows");
        }

        //if supply balance > 0, there are no borrowing so no repay, withdraw instead.
        require(IComet(market).balanceOf(to) == 0, "cannot-repay-when-supplied");

        IComet(market).supplyFrom(from, to, token, amount);
    }

    function buyCollateral(
        address market,
        address sellToken,
        address buyAsset,
        uint256 unitamount,
        uint256 baseSellamount
    ) external payable {
        _buyCollateral(
            BuyCollateralData({
                market: market,
                sellToken: sellToken,
                buyAsset: buyAsset,
                unitamount: unitamount,
                baseSellamount: baseSellamount
            })
        );
    }

    function transferAsset(address market, address token, address dest, uint256 amount) external payable {
        require(market != address(0) && token != address(0) && dest != address(0), "invalid market/token/to address");

        amount = amount == type(uint).max ? _getAccountSupplyBalanceOfAsset(address(this), market, token) : amount;

        IComet(market).transferAssetFrom(address(this), dest, token, amount);
    }

    function transferAssetOnBehalf(
        address market,
        address token,
        address src,
        address dest,
        uint256 amount
    ) external payable {
        require(market != address(0) && token != address(0) && dest != address(0), "invalid market/token/to address");

        amount = amount == type(uint).max ? _getAccountSupplyBalanceOfAsset(src, market, token) : amount;

        IComet(market).transferAssetFrom(src, dest, token, amount);
    }

    function toggleAccountManager(address market, address manager, bool isAllowed) external {
        IComet(market).allow(manager, isAllowed);
    }

    function toggleAccountManagerWithPermit(
        address market,
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IComet(market).allowBySig(owner, manager, isAllowed, nonce, expiry, v, r, s);
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
            //if there are supplies, ensure withdrawn amount is not greater than supplied i.e can't borrow using withdraw.
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

    function _calculateFromAmount(
        address market,
        address token,
        address src,
        uint256 amount,
        Action action
    ) internal view returns (uint256) {
        if (amount == type(uint).max) {
            uint256 allowance = IERC20(token).allowance(src, market);
            uint256 balance;

            if (action == Action.REPAY) {
                balance = IComet(market).borrowBalanceOf(src);
            } else if (action == Action.DEPOSIT) {
                balance = IERC20(token).balanceOf(src);
            }

            amount = balance < allowance ? balance : allowance;
        }

        return amount;
    }

    function _buyCollateral(BuyCollateralData memory params) internal {
        uint256 sellAmount = params.baseSellamount;
        require(params.market != address(0) && params.buyAsset != address(0), "invalid market/token address");
        require(params.sellToken == getBaseToken(params.market), "invalid-sell-token");

        if (sellAmount == type(uint).max) {
            sellAmount = IERC20(params.sellToken).balanceOf(address(this));
        }

        uint256 slippageAmount = convert18ToDec(
            IERC20(params.buyAsset).universalDecimals(),
            params.unitamount * convertTo18(IERC20(params.sellToken).universalDecimals(), sellAmount)
        );

        uint256 initialCollBalance = IERC20(params.buyAsset).balanceOf(address(this));

        IERC20(params.sellToken).universalApprove(params.market, sellAmount);
        IComet(params.market).buyCollateral(params.buyAsset, slippageAmount, sellAmount, address(this));

        uint256 finalCollBalance = IERC20(params.buyAsset).balanceOf(address(this));

        uint256 buyamount = finalCollBalance - initialCollBalance;
        require(slippageAmount <= buyamount, "too much slippage");
    }

    function convert18ToDec(uint _decimals, uint256 _amount) internal pure returns (uint256 amount) {
        amount = (_amount / 10 ** (18 - _decimals));
    }

    function convertTo18(uint _decimals, uint256 _amount) internal pure returns (uint256 amount) {
        amount = _amount * (10 ** (18 - _decimals));
    }
}
