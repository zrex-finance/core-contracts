// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces.sol";

contract Variables {
    IAaveLending internal constant aaveLending = IAaveLending(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IERC3156FlashLender internal constant makerLending = IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
    IBalancerLending internal constant balancerLending = IBalancerLending(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    bytes32 internal dataHash;
    // if 1 then can enter flashlaon, if 2 then callback
    uint256 internal status;
}
