// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../lib/UniversalERC20.sol";

import { IWeth } from "./interfaces.sol";

abstract contract EthConverter {
    using UniversalERC20 for IERC20;

    IWeth constant internal wethAddr = IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function convertEthToWeth(address token, uint amount) internal {
        if (IERC20(token).isETH()) {
            wethAddr.deposit{value: amount}();
        }
    }

    function convertWethToEth(address token, uint amount) internal {
       if(IERC20(token).isETH()) {
            IERC20(token).universalApprove(address(wethAddr), amount);
            wethAddr.withdraw(amount);
        }
    }
}

abstract contract Basic is EthConverter {

    function convert18ToDec(uint _decimals, uint256 _amount) internal pure returns (uint256 amount) {
        amount = (_amount / 10 ** (18 - _decimals));
    }

    function convertTo18(uint _decimals, uint256 _amount) internal pure returns (uint256 amount) {
        amount = _amount * (10 ** (18 - _decimals)) ;
    }

    function getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        if (_returnData.length < 68) {
            return "Transaction reverted silently";
        }

        assembly {
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string));
    }
}
