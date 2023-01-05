// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Connectors, TokenInterface } from "./interfaces.sol";

abstract contract Stores {
  address constant internal ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address constant internal wethAddr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  Connectors internal constant connectors = Connectors(0x97b0B3A8bDeFE8cB9563a3c610019Ad10DB8aD11);
}