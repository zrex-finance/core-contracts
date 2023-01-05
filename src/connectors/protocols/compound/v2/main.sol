// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Stores, TokenInterface } from "../../../common/base.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";
import { CETHInterface, CTokenInterface } from "./interface.sol";

abstract contract CompoundResolver is Events, Helpers {
    function depositRaw(
        address token,
        address cToken,
        uint256 amt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);
        if (token == ethAddr) {
            amt = amt == type(uint).max ? address(this).balance : amt;
            CETHInterface(cToken).mint{value: amt}();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            amt = amt == type(uint).max ? tokenContract.balanceOf(address(this)) : amt;
            approve(tokenContract, cToken, amt);
            require(CTokenInterface(cToken).mint(amt) == 0, "deposit-failed");
        }

        _eventName = "LogDeposit(address,address,uint256)";
        _eventParam = abi.encode(token, cToken, amt);
    }

    function deposit(
        string calldata tokenId,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        (_eventName, _eventParam) = depositRaw(token, cToken, amt);
    }

    function withdrawRaw(
        address token,
        address cToken,
        uint256 amt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        CTokenInterface cTokenContract = CTokenInterface(cToken);
        if (amt == type(uint).max) {
            TokenInterface tokenContract = TokenInterface(token);
            uint initialBal = token == ethAddr ? address(this).balance : tokenContract.balanceOf(address(this));
            require(cTokenContract.redeem(cTokenContract.balanceOf(address(this))) == 0, "full-withdraw-failed");
            uint finalBal = token == ethAddr ? address(this).balance : tokenContract.balanceOf(address(this));
            amt = finalBal - initialBal;
        } else {
            require(cTokenContract.redeemUnderlying(amt) == 0, "withdraw-failed");
        }

        _eventName = "LogWithdraw(address,address,uint256)";
        _eventParam = abi.encode(token, cToken, amt);
    }

    function withdraw(
        string calldata tokenId,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        (_eventName, _eventParam) = withdrawRaw(token, cToken, amt);
    }

    function borrowRaw(
        address token,
        address cToken,
        uint256 amt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);
        require(CTokenInterface(cToken).borrow(amt) == 0, "borrow-failed");

        _eventName = "LogBorrow(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, amt);
    }

    function borrow(
        string calldata tokenId,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        (_eventName, _eventParam) = borrowRaw(token, cToken, amt);
    }

    function paybackRaw(
        address token,
        address cToken,
        uint256 amt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        CTokenInterface cTokenContract = CTokenInterface(cToken);
        amt = amt == type(uint).max ? cTokenContract.borrowBalanceCurrent(address(this)) : amt;

        if (token == ethAddr) {
            require(address(this).balance >= amt, "not-enough-eth");
            CETHInterface(cToken).repayBorrow{value: amt}();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            require(tokenContract.balanceOf(address(this)) >= amt, "not-enough-token");
            approve(tokenContract, cToken, amt);
            require(cTokenContract.repayBorrow(amt) == 0, "repay-failed.");
        }

        _eventName = "LogPayback(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, amt);
    }

    function payback(
        string calldata tokenId,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        (_eventName, _eventParam) = paybackRaw(token, cToken, amt);
    }

    function depositCTokenRaw(
        address token,
        address cToken,
        uint256 amt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);

        CTokenInterface ctokenContract = CTokenInterface(cToken);
        uint initialBal = ctokenContract.balanceOf(address(this));

        if (token == ethAddr) {
            amt = amt == type(uint).max ? address(this).balance : amt;
            CETHInterface(cToken).mint{value: amt}();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            amt = amt == type(uint).max ? tokenContract.balanceOf(address(this)) : amt;
            approve(tokenContract, cToken, amt);
            require(ctokenContract.mint(amt) == 0, "deposit-ctoken-failed.");
        }

        uint _cAmt;

        {
            uint finalBal = ctokenContract.balanceOf(address(this));
            _cAmt = finalBal - initialBal;
        }

        _eventName = "LogDepositCToken(address,address,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, amt, _cAmt);
    }

    function depositCToken(
        string calldata tokenId,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        (_eventName, _eventParam) = depositCTokenRaw(token, cToken, amt);
    }

    function withdrawCTokenRaw(
        address token,
        address cToken,
        uint cTokenAmt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        CTokenInterface cTokenContract = CTokenInterface(cToken);
        TokenInterface tokenContract = TokenInterface(token);
        cTokenAmt = cTokenAmt == type(uint).max ? cTokenContract.balanceOf(address(this)) : cTokenAmt;

        uint withdrawAmt;
        {
            uint initialBal = token != ethAddr ? tokenContract.balanceOf(address(this)) : address(this).balance;
            require(cTokenContract.redeem(cTokenAmt) == 0, "redeem-failed");
            uint finalBal = token != ethAddr ? tokenContract.balanceOf(address(this)) : address(this).balance;

            withdrawAmt = finalBal - initialBal;
        }

        _eventName = "LogWithdrawCToken(address,address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, cToken, withdrawAmt, cTokenAmt);
    }

    function withdrawCToken(
        string calldata tokenId,
        uint cTokenAmt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        (_eventName, _eventParam) = withdrawCTokenRaw(token, cToken, cTokenAmt);
    }

    function liquidateRaw(
        address borrower,
        address tokenToPay,
        address cTokenPay,
        address tokenInReturn,
        address cTokenColl,
        uint256 amt
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(tokenToPay != address(0) && cTokenPay != address(0), "invalid token/ctoken address");
        require(tokenInReturn != address(0) && cTokenColl != address(0), "invalid token/ctoken address");

        CTokenInterface cTokenContract = CTokenInterface(cTokenPay);

        {
            (,, uint shortfal) = troller.getAccountLiquidity(borrower);
            require(shortfal != 0, "account-cannot-be-liquidated");
            amt = amt == type(uint).max ? cTokenContract.borrowBalanceCurrent(borrower) : amt;
        }

        if (tokenToPay == ethAddr) {
            require(address(this).balance >= amt, "not-enought-eth");
            CETHInterface(cTokenPay).liquidateBorrow{value: amt}(borrower, cTokenColl);
        } else {
            TokenInterface tokenContract = TokenInterface(tokenToPay);
            require(tokenContract.balanceOf(address(this)) >= amt, "not-enough-token");
            approve(tokenContract, cTokenPay, amt);
            require(cTokenContract.liquidateBorrow(borrower, amt, cTokenColl) == 0, "liquidate-failed");
        }

        _eventName = "LogLiquidate(address,address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(address(this),tokenToPay,tokenInReturn, amt);
    }

    function liquidate(
        address borrower,
        string calldata tokenIdToPay,
        string calldata tokenIdInReturn,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address tokenToPay, address cTokenToPay) = compMapping.getMapping(tokenIdToPay);
        (address tokenInReturn, address cTokenColl) = compMapping.getMapping(tokenIdInReturn);

        (_eventName, _eventParam) = liquidateRaw(
            borrower,
            tokenToPay,
            cTokenToPay,
            tokenInReturn,
            cTokenColl,
            amt
        );
    }
}

contract ConnectV2Compound is CompoundResolver {
    string public name = "Compound-v1.1";
}
