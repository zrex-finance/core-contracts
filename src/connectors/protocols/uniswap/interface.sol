// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../../common/interfaces.sol";

struct SwapData {
	TokenInterface sellToken;
	TokenInterface buyToken;
	uint256 _sellAmt;
	uint256 _buyAmt;
	uint256 unitAmt;
	bytes callData;
}
