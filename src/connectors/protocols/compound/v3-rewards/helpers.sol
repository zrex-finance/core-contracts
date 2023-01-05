// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../../../common/interfaces.sol";
import { DSMath } from "../../../common/math.sol";
import { Basic } from "../../../common/basic.sol";
import {  CometRewards } from "./interface.sol";

abstract contract Helpers is DSMath, Basic {
	CometRewards internal constant cometRewards =
		CometRewards(0x1B0e765F6224C21223AeA2af16c1C46E38885a40);
}
