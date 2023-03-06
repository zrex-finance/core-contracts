// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { IWeth } from "./Interfaces.sol";

abstract contract EthConverter {
    using UniversalERC20 for IERC20;

    IWeth constant internal wethAddr = IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function convertEthToWeth(address token, uint amount) internal {
        if (IERC20(token).isETH()) {
            wethAddr.deposit{value: amount}();
        }
    }

    function convertWethToEth(address token, uint amount) internal {
       if(token == address(wethAddr)) {
            IERC20(token).universalApprove(address(wethAddr), amount);
            wethAddr.withdraw(amount);
        }
    }
}

