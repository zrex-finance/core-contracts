// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { ICToken, IComptroller, ICompoundMapping } from "./interfaces/CompoundV2.sol";

contract CompoundV2Connector {
    using UniversalERC20 for IERC20;

    IComptroller internal constant troller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    ICompoundMapping internal constant compMapping = ICompoundMapping(0x2e234DAe75C793f67A35089C9d99245E1C58470b);

    string public constant name = "CompoundV2";

    function deposit(address token, uint256 amount) external payable {
        address cToken = compMapping.cTokenMapping(token);
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);

        IERC20 tokenC = IERC20(token);
        amount = amount == type(uint).max ? tokenC.balanceOf(address(this)) : amount;
        tokenC.universalApprove(cToken, amount);

        require(ICToken(cToken).mint(amount) == 0, "deposit failed");
    }

    function withdraw(address token, uint256 amount) external payable {
        address cToken = compMapping.cTokenMapping(token);
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        ICToken ctokenC = ICToken(cToken);

        if (amount == type(uint).max) {
            require(ctokenC.redeem(ctokenC.balanceOf(address(this))) == 0, "full withdraw failed");
        } else {
            require(ctokenC.redeemUnderlying(amount) == 0, "withdraw failed");
        }
    }

    function borrow(address token, uint256 amount) external payable {
        address cToken = compMapping.cTokenMapping(token);
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        enterMarket(cToken);
        require(ICToken(cToken).borrow(amount) == 0, "borrow failed");
    }

    function payback(address token, uint256 amount) external payable {
        address cToken = compMapping.cTokenMapping(token);
        require(token != address(0) && cToken != address(0), "invalid token/ctoken address");

        ICToken ctokenC = ICToken(cToken);
        amount = amount == type(uint).max ? ctokenC.borrowBalanceCurrent(address(this)) : amount;

        IERC20 tokenC = IERC20(token);
        require(tokenC.balanceOf(address(this)) >= amount, "not enough token");

        tokenC.universalApprove(cToken, amount);
        require(ctokenC.repayBorrow(amount) == 0, "repay failed.");
    }

    function borrowBalanceOf(address _token, address _recipient) public returns (uint256) {
        address cToken = compMapping.cTokenMapping(_token);
        require(_token != address(0) && cToken != address(0), "invalid token/ctoken address");
        return ICToken(cToken).borrowBalanceCurrent(_recipient);
    }

    function collateralBalanceOf(address _token, address _recipient) public returns (uint256) {
        address cToken = compMapping.cTokenMapping(_token);
        require(_token != address(0) && cToken != address(0), "invalid token/ctoken address");
        return ICToken(cToken).balanceOfUnderlying(_recipient);
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
