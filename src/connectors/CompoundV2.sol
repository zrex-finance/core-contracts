// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { ICToken, IComptroller, ICompoundMapping } from "./interfaces/CompoundV2.sol";

contract CompoundV2Connector {
    using UniversalERC20 for IERC20;

    IComptroller internal constant troller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    ICompoundMapping internal constant compMapping = ICompoundMapping(0xe7a85d0adDB972A4f0A4e57B698B37f171519e88);

    string public constant name = "CompoundV2";

    function depositRaw(address token,address cToken,uint256 amount) public payable {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);

        IERC20 tokenC = IERC20(token);
        amount = amount == type(uint).max 
            ? tokenC.balanceOf(address(this)) 
            : amount;
        tokenC.universalApprove(cToken, amount);

        require(ICToken(cToken).mint(amount) == 0, "deposit failed");
    }

    function deposit(string calldata tokenId,uint256 amount) external payable {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        depositRaw(token, cToken, amount);
    }

    function withdrawRaw(address token,address cToken,uint256 amount) public payable {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        ICToken ctokenC = ICToken(cToken);

        if (amount == type(uint).max) {
            require(ctokenC.redeem(ctokenC.balanceOf(address(this))) == 0, "full withdraw failed");
        } else {
            require(ctokenC.redeemUnderlying(amount) == 0, "withdraw failed");
        }
    }

    function withdraw(string calldata tokenId,uint256 amount) external payable {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        withdrawRaw(token, cToken, amount);
    }

    function borrowRaw(address token,address cToken,uint256 amount) public payable {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);
        require(ICToken(cToken).borrow(amount) == 0, "borrow failed");
    }

    function borrow(string calldata tokenId,uint256 amount) external payable {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        borrowRaw(token, cToken, amount);
    }

    function paybackRaw(address token,address cToken,uint256 amount) public payable {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        ICToken ctokenC = ICToken(cToken);
        amount = amount == type(uint).max 
            ? ctokenC.borrowBalanceCurrent(address(this)) 
            : amount;

        IERC20 tokenC = IERC20(token);
        require(tokenC.balanceOf(address(this)) >= amount, "not enough token");

        tokenC.universalApprove(cToken, amount);
        require(ctokenC.repayBorrow(amount) == 0, "repay failed.");
    }

    function payback(string calldata tokenId,uint256 amount) external payable {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        paybackRaw(token, cToken, amount);
    }

    function depositCTokenRaw(address token,address cToken,uint256 amount) public payable {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);

        ICToken ctokenC = ICToken(cToken);
        IERC20 tokenC = IERC20(token);

        amount = amount == type(uint).max 
            ? tokenC.balanceOf(address(this)) 
            : amount;

        tokenC.universalApprove(cToken, amount);
        require(ctokenC.mint(amount) == 0, "deposit-ctoken-failed.");
    }

    function depositCToken(string calldata tokenId,uint256 amount) external payable {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        depositCTokenRaw(token, cToken, amount);
    }

    function withdrawCTokenRaw(address token,address cToken,uint cTokenAmount) public payable {
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        ICToken ctokenC = ICToken(cToken);

        cTokenAmount = cTokenAmount == type(uint).max 
            ? ctokenC.balanceOf(address(this)) 
            : cTokenAmount;

        require(ctokenC.redeem(cTokenAmount) == 0, "redeem-failed");
    }

    function withdrawCToken(string calldata tokenId,uint cTokenamount) external payable {
        (address token, address cToken) = compMapping.getMapping(tokenId);
        withdrawCTokenRaw(token, cToken, cTokenamount);
    }

    function liquidateRaw(
        address borrower,
        address tokenToPay,
        address cTokenPay,
        address tokenInReturn,
        address cTokenColl,
        uint256 amount
    ) public payable {
        require(tokenToPay != address(0) && cTokenPay != address(0), "invalid token/ctoken address");
        require(tokenInReturn != address(0) && cTokenColl != address(0), "invalid token/ctoken address");

        ICToken ctokenC = ICToken(cTokenPay);

        (,, uint shortfal) = troller.getAccountLiquidity(borrower);
        require(shortfal != 0, "account cannot be liquidated");
            
        amount = amount == type(uint).max 
            ? ctokenC.borrowBalanceCurrent(borrower) 
            : amount;

        IERC20 tokenC = IERC20(tokenToPay);
        require(tokenC.balanceOf(address(this)) >= amount, "not enough token");

        tokenC.universalApprove(cTokenPay, amount);
        require(ctokenC.liquidateBorrow(borrower, amount, cTokenColl) == 0, "liquidate failed");
    }

    function liquidate(
        address borrower,
        string calldata tokenIdToPay,
        string calldata tokenIdInReturn,
        uint256 amount
    ) external payable {
        (address tokenToPay, address cTokenToPay) = compMapping.getMapping(tokenIdToPay);
        (address tokenInReturn, address cTokenColl) = compMapping.getMapping(tokenIdInReturn);

        liquidateRaw(
            borrower,
            tokenToPay,
            cTokenToPay,
            tokenInReturn,
            cTokenColl,
            amount
        );
    }

    function enterMarket(address cToken) internal {
        address[] memory markets = troller.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint i = 0; i < markets.length; i++) {
            if (markets[i] == cToken) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cToken;
            troller.enterMarkets(toEnter);
        }
    }
}

