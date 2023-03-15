// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "../dependencies/openzeppelin/contracts/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { IWeth } from "./interfaces/EthConverter.sol";

abstract contract EthConverter {
    using UniversalERC20 for IERC20;

    IWeth internal constant wethAddr = IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function convertEthToWeth(address token, uint amount) internal {
        if (IERC20(token).isETH()) {
            wethAddr.deposit{ value: amount }();
        }
    }

    function convertWethToEth(address token, uint amount) internal {
        if (token == address(wethAddr)) {
            IERC20(token).universalApprove(address(wethAddr), amount);
            wethAddr.withdraw(amount);
        }
    }
}
