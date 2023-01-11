// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../../../common/interfaces.sol";
import { Basic } from "../../../common/base.sol";

abstract contract Helpers is Basic {
    address internal constant oneInchAddr = 0x11111112542D85B3EF69AE05771c2dCCff4fAa26;
    
    bytes4 internal constant oneInchSwapSig = 0x7c025200;

    bytes4 internal constant oneInchUnoswapSig = 0x2e95b6c8;
}