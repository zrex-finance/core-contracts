// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface TokenInterface {
    function approve(address, uint256) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint256);
    function isETH(TokenInterface token) external pure returns(bool);
}

interface IWeth {
    function deposit() external payable;
    function withdraw(uint wad) external;
}