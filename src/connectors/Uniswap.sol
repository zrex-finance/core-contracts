// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "../dependencies/openzeppelin/contracts/IERC20.sol";

import { EthConverter } from "../utils/EthConverter.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

contract UniswapConnector is EthConverter {
    using UniversalERC20 for IERC20;

    string public name = "UniswapAuto";

    /**
     * @dev UniswapV3 Auto Swap Router Address
     */
    address internal constant uniAutoRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    /**
     * @dev Sell ETH/ERC20_Token using uniswap v3 auto router.
     * @notice Swap tokens from getting an optimized trade routes
     * @param _toToken The address of the token to buy.
     * @param _fromToken The address of the token to sell.
     * @param _amount The amount of the token to sell.
     * @param _callData Data from uniswap API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) external payable returns (uint256 buyAmount) {
        buyAmount = _swap(_toToken, _fromToken, _amount, _callData);
        emit LogExchange(msg.sender, _toToken, _fromToken, _amount);
    }

    /**
     * @dev Universal approve tokens to uniswap router and execute calldata.
     * @param _toToken The address of the token to buy.
     * @param _fromToken The address of the token to sell.
     * @param _amount The amount of the token to sell.
     * @param _callData Data from uniswap API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function _swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) internal returns (uint256 buyAmount) {
        IERC20(_fromToken).universalApprove(uniAutoRouter, _amount);

        uint256 initalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = uniAutoRouter.call(_callData);

        if (!success) {
            revert(_getRevertMsg(results));
        }

        uint256 finalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) {
            return "Transaction reverted silently";
        }

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    event LogExchange(address indexed account, address buyAddr, address sellAddr, uint256 sellAmt);
}
