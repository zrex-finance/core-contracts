// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IKyber {
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    ) external payable returns (uint);

    function getExpectedRate(address src, address dest, uint srcQty) external view returns (uint, uint);
}
