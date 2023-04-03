// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { SafeERC20 } from 'contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';

contract HelperContract is Test {
    using SafeERC20 for ERC20;

    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;
    address usdtWhale = 0xee5B5B923fFcE93A870B3104b7CA09c3db80047A;
    address usdcWhale = 0x5414d89a8bF7E99d732BC52f3e6A3Ef461c0C078;

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).safeTransfer(msg.sender, amt);
    }
}
