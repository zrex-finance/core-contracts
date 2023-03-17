// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "../dependencies/openzeppelin/contracts/IERC20.sol";

import { EthConverter } from "../utils/EthConverter.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

contract InchV5Connector is EthConverter {
    using UniversalERC20 for IERC20;

    string public constant name = "1Inch-v5";

    /**
     * @dev 1Inch Router v5 Address
     */
    address internal constant oneInchV5 = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    /**
     * @dev Swap ETH/ERC20_Token using 1Inch.
     * @notice Swap tokens from exchanges like kyber, 0x etc, with calculation done off-chain.
     * @param _toToken The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _fromToken The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to sell.
     * @param _callData Data from 1inch API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) external payable returns (uint256 buyAmount) {
        buyAmount = _swap(_toToken, _fromToken, _amount, _callData);
        convertEthToWeth(_toToken, buyAmount);
        emit LogExchange(msg.sender, _toToken, _fromToken, _amount);
    }

    /**
     * @dev Universal approve tokens to inch router and execute calldata.
     * @param _toToken The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _fromToken The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to sell.
     * @param _callData Data from 1inch API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function _swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) internal returns (uint256 buyAmount) {
        IERC20(_fromToken).universalApprove(oneInchV5, _amount);

        uint256 value = IERC20(_fromToken).isETH() ? _amount : 0;

        uint256 initalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = oneInchV5.call{ value: value }(_callData);

        if (!success) {
            revert(string(results));
        }

        uint256 finalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }

    event LogExchange(address indexed account, address buyAddr, address sellAddr, uint256 sellAmt);
}
