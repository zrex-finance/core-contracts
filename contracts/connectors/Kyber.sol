// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IKyber } from '../interfaces/external/kyber/IKyber.sol';
import { IKyberConnector } from '../interfaces/connectors/IKyberConnector.sol';

import { UniversalERC20 } from '../lib/UniversalERC20.sol';

contract KyberConnector is IKyberConnector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    string public constant name = 'CompoundV3';
    /**
     * @dev Kyber Interface
     */
    IKyber internal constant kyber = IKyber(0x818E6FECD516Ecc3849DAf6845e3EC868087B755);

    // TODO change this address
    address internal constant referral = 0x444444Cc7FE267251797d8592C3f4d5EE6888D62;

    /* ============ Events ============ */

    /**
     * @dev Emitted when the sender swap tokens.
     * @param account Address who create operation.
     * @param fromToken The address of the token to sell.
     * @param toToken The address of the token to buy.
     * @param amount The amount of the token to sell.
     */
    event LogExchange(address indexed account, address toToken, address fromToken, uint256 amount);

    /* ============ External Functions ============ */

    /**
     * @dev Sell ETH/ERC20_Token using Kyber.
     * @notice Swap tokens from getting an optimized trade routes
     * @param _toToken The address of the token to buy.
     * @param _fromToken The address of the token to sell.
     * @param _amount The amount of the token to sell.
     * @return buyAmount Returns the amount of tokens received.
     */
    function swap(address _toToken, address _fromToken, uint256 _amount) external payable returns (uint256 buyAmount) {
        buyAmount = _swap(_toToken, _fromToken, _amount);
        emit LogExchange(msg.sender, _toToken, _fromToken, _amount);
    }

    /**
     * @dev Universal approve tokens to uniswap router and execute calldata.
     * @param _toToken The address of the token to buy.
     * @param _fromToken The address of the token to sell.
     * @param _amount The amount of the token to sell.
     * @return buyAmount Returns the amount of tokens received.
     */
    function _swap(address _toToken, address _fromToken, uint256 _amount) internal returns (uint256 buyAmount) {
        IERC20(_fromToken).universalApprove(address(kyber), _amount);

        uint256 value = IERC20(_fromToken).isETH() ? _amount : 0;

        uint256 initalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        kyber.trade{ value: value }(_fromToken, _amount, _toToken, address(this), 0, 0, referral);

        uint256 finalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }
}
