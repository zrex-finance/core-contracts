// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Connectors, TokenInterface } from "./interfaces.sol";
import { Stores } from "./stores.sol";

abstract contract Basic is Stores {

    function convert18ToDec(uint _decimals, uint256 _amount) internal pure returns (uint256 amount) {
        amount = (_amount / 10 ** (18 - _decimals));
    }

    function convertTo18(uint _decimals, uint256 _amount) internal pure returns (uint256 amount) {
        amount = _amount * (10 ** (18 - _decimals)) ;
    }

    function getTokenBalance(TokenInterface token) internal view returns(uint amount) {
        amount = isETH(address(token)) ? address(this).balance : token.balanceOf(address(this));
    }

    function getTokensDecimals(TokenInterface _token1, TokenInterface _token2) internal view returns(uint token1Dec, uint token2Dec) {
        token1Dec = isETH(address(_token1)) ?  18 : _token1.decimals();
        token2Dec = isETH(address(_token2)) ?  18 : _token2.decimals();
    }

    function encodeEvent(string memory eventName, bytes memory eventParam) internal pure returns (bytes memory) {
        return abi.encode(eventName, eventParam);
    }

    function approve(TokenInterface token, address spender, uint256 amount) internal {
        try token.approve(spender, amount) {

        } catch {
            token.approve(spender, 0);
            token.approve(spender, amount);
        }
    }

    function changeEthAddress(address buy, address sell) internal pure returns(TokenInterface _buy, TokenInterface _sell){
        _buy = isETH(buy) ? TokenInterface(wethAddr) : TokenInterface(buy);
        _sell = isETH(sell) ? TokenInterface(wethAddr) : TokenInterface(sell);
    }

    function changeEthAddrToWethAddr(address token) internal pure returns(address tokenAddr){
        tokenAddr = isETH(token) ? wethAddr : token;
    }

    function convertEthToWeth(bool isEth, TokenInterface token, uint amount) internal {
        if(isEth) token.deposit{value: amount}();
    }

    function convertWethToEth(bool isEth, TokenInterface token, uint amount) internal {
       if(isEth) {
            approve(token, address(token), amount);
            token.withdraw(amount);
        }
    }

    function isETH(address token) internal pure returns(bool) {
        return (address(token) == address(zeroAddr) || address(token) == address(ethAddr));
    }
}
