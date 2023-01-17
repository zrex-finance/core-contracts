// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces.sol";

contract ConstantVariables {
    IAaveLending internal constant aaveLending = IAaveLending(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IERC3156FlashLender internal constant makerLending = IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
    IBalancerLending internal constant balancerLending = IBalancerLending(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address internal constant treasuryAddr = 0x28849D2b63fA8D361e5fc15cB8aBB13019884d09;
    uint256 public constant FeeBPS = 5; // in BPS; 1 BPS = 0.01%
}

contract Variables is ConstantVariables {
    bytes32 internal dataHash;
    // if 1 then can enter flashlaon, if 2 then callback
    uint256 internal status;

    struct FlashloanVariables {
        address[] _tokens;
        uint256[] _amounts;
        uint256[] _iniBals;
        uint256[] _finBals;
        uint256[] _fees;
    }

    address public owner;
}
