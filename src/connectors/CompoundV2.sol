// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { ICToken, IComptroller, ICompoundMapping } from "./interfaces/CompoundV2.sol";

contract CompoundV2Connector {
    using UniversalERC20 for IERC20;

    IComptroller internal constant troller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    string public constant name = "CompoundV2";

    function deposit(address token, uint256 amount) external payable {
        ICToken cToken = _getCToken(token);

        enterMarket(address(cToken));

        IERC20 tokenC = IERC20(token);
        amount = amount == type(uint).max ? tokenC.balanceOf(address(this)) : amount;
        tokenC.universalApprove(address(cToken), amount);

        ICToken(cToken).mint(amount);
    }

    function withdraw(address token, uint256 amount) external payable {
        ICToken cToken = _getCToken(token);

        if (amount == type(uint).max) {
            cToken.redeem(cToken.balanceOf(address(this)));
        } else {
            cToken.redeemUnderlying(amount);
        }
    }

    function borrow(address token, uint256 amount) external payable {
        ICToken cToken = _getCToken(token);

        enterMarket(address(cToken));
        ICToken(cToken).borrow(amount);
    }

    function payback(address token, uint256 amount) external payable {
        ICToken cToken = _getCToken(token);

        amount = amount == type(uint).max ? cToken.borrowBalanceCurrent(address(this)) : amount;

        IERC20 tokenC = IERC20(token);
        require(tokenC.balanceOf(address(this)) >= amount, "not enough token");

        tokenC.universalApprove(address(cToken), amount);
        cToken.repayBorrow(amount);
    }

    function borrowBalanceOf(address _token, address _recipient) public returns (uint256) {
        ICToken cToken = _getCToken(_token);
        return cToken.borrowBalanceCurrent(_recipient);
    }

    function collateralBalanceOf(address _token, address _recipient) public returns (uint256) {
        ICToken cToken = _getCToken(_token);
        return cToken.balanceOfUnderlying(_recipient);
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

    function _getCToken(address _token) public pure returns (ICToken) {
        if (IERC20(_token).isETH()) {
            // ETH
            return ICToken(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
        }
        if (_token == 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9) {
            // AAVE
            return ICToken(0xe65cdB6479BaC1e22340E4E755fAE7E509EcD06c);
        }
        if (_token == 0x0D8775F648430679A709E98d2b0Cb6250d2887EF) {
            // BAT
            return ICToken(0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E);
        }
        if (_token == 0xc00e94Cb662C3520282E6f5717214004A7f26888) {
            return ICToken(0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4);
        }
        if (_token == 0x6B175474E89094C44Da98b954EedeAC495271d0F) {
            // DAI
            return ICToken(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        }
        if (_token == 0x956F47F50A910163D8BF957Cf5846D573E7f87CA) {
            // FEI
            return ICToken(0x7713DD9Ca933848F6819F38B8352D9A15EA73F67);
        }
        if (_token == 0x514910771AF9Ca656af840dff83E8264EcF986CA) {
            // LINK
            return ICToken(0xFAce851a4921ce59e912d19329929CE6da6EB0c7);
        }
        if (_token == 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2) {
            // MAKER
            return ICToken(0x95b4eF2869eBD94BEb4eEE400a99824BF5DC325b);
        }
        if (_token == 0x1985365e9f78359a9B6AD760e32412f4a445E862) {
            // REP
            return ICToken(0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1);
        }
        if (_token == 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359) {
            // SAI
            return ICToken(0xF5DCe57282A584D2746FaF1593d3121Fcac444dC);
        }
        if (_token == 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2) {
            // SUSHI
            return ICToken(0x4B0181102A0112A2ef11AbEE5563bb4a3176c9d7);
        }
        if (_token == 0x0000000000085d4780B73119b644AE5ecd22b376) {
            // TUSD
            return ICToken(0x12392F67bdf24faE0AF363c24aC620a2f67DAd86);
        }
        if (_token == 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984) {
            // UNI
            return ICToken(0x35A18000230DA775CAc24873d00Ff85BccdeD550);
        }
        if (_token == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
            // USDC
            return ICToken(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
        }
        if (_token == 0x8E870D67F660D95d5be530380D0eC0bd388289E1) {
            // USDP
            return ICToken(0x041171993284df560249B57358F931D9eB7b925D);
        }
        if (_token == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
            // USDT
            return ICToken(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9);
        }
        if (_token == 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599) {
            // WBTC
            return ICToken(0xccF4429DB6322D5C611ee964527D42E5d685DD6a);
        }
        if (_token == 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e) {
            // YFI
            return ICToken(0x80a2AE356fc9ef4305676f7a3E2Ed04e12C33946);
        }
        if (_token == 0xE41d2489571d322189246DaFA5ebDe1F4699F498) {
            // ZRX
            return ICToken(0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407);
        }

        revert("Unsupported token");
    }
}
