// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { SafeERC20 } from 'contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';

import { Tokens } from './tokens.sol';

contract HelperContract is Tokens, Test {
    using SafeERC20 for ERC20;

    function topUpTokenBalance(address _recipient, address _token, uint256 _amount) public {
        address whale = getWhaleFromToken(_token);
        // top up msg sender balance
        vm.prank(whale);
        ERC20(_token).safeTransfer(_recipient, _amount);
    }

    function getWhaleFromToken(address _token) public view returns (address) {
        uint256 chainId = getChainID();

        if (chainId == 1) {
            if (_token == getToken('usdc')) {
                return 0xDa9CE944a37d218c3302F6B82a094844C6ECEb17;
            } else if (_token == getToken('dai')) {
                return getToken('dai');
            } else if (_token == getToken('weth')) {
                return getToken('weth');
            }
        } else if (chainId == 137) {
            if (_token == getToken('usdc')) {
                return 0x19aB546E77d0cD3245B2AAD46bd80dc4707d6307;
            } else if (_token == getToken('dai')) {
                return 0x79990a901281bEe059BB3F4D7Db477F7495e2049;
            } else if (_token == getToken('weth')) {
                return 0x62ac55b745F9B08F1a81DCbbE630277095Cf4Be1;
            }
        } else {
            require(false, 'dont have whale');
        }
    }
}
