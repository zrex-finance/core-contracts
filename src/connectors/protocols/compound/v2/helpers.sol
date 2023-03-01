// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Basic } from "../../../common/base.sol";
import { IComptroller, ICompoundMapping } from "./interface.sol";

abstract contract Helpers is Basic {

    IComptroller internal constant troller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    ICompoundMapping internal constant compMapping = ICompoundMapping(0xe7a85d0adDB972A4f0A4e57B698B37f171519e88);

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
