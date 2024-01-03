// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import { IVixConnector } from '../../interfaces/connectors/IVixConnector.sol';
import { CErc20Interface } from '../../interfaces/external/compound-v2/CTokenInterfaces.sol';
import { ComptrollerInterface } from '../../interfaces/external/compound-v2/ComptrollerInterface.sol';

import { UniversalERC20 } from '../../lib/UniversalERC20.sol';

contract VixConnector is IVixConnector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Vix COMPTROLLER
     */
    ComptrollerInterface internal constant COMPTROLLER =
        ComptrollerInterface(0x6EA32f626e3A5c41547235ebBdf861526e11f482);

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'Vix';

    /* ============ External Functions ============ */

    /**
     * @dev Deposit ETH/ERC20_Token using the Mapping.
     * @notice Deposit a token to Vix for lending / collaterization.
     * @param _token The address of the token to deposit. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to deposit. (For max: `type(uint).max`)
     */
    function deposit(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        enterMarket(address(cToken));

        IERC20 tokenC = IERC20(_token);
        _amount = _amount == type(uint).max ? tokenC.balanceOf(address(this)) : _amount;
        tokenC.universalApprove(address(cToken), _amount);

        CErc20Interface(cToken).mint(_amount);
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @notice Withdraw deposited token from Vix
     * @param _token The address of the token to withdraw. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to withdraw. (For max: `type(uint).max`)
     */
    function withdraw(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        if (_amount == type(uint).max) {
            cToken.redeem(cToken.balanceOf(address(this)));
        } else {
            cToken.redeemUnderlying(_amount);
        }
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @notice Borrow a token using Vix
     * @param _token The address of the token to borrow. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to borrow.
     */
    function borrow(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        enterMarket(address(cToken));
        CErc20Interface(cToken).borrow(_amount);
    }

    /**
     * @dev Payback borrowed ETH/ERC20_Token.
     * @notice Payback debt owed.
     * @param _token The address of the token to payback. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to payback. (For max: `type(uint).max`)
     */
    function payback(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        _amount = _amount == type(uint).max ? cToken.borrowBalanceCurrent(address(this)) : _amount;

        IERC20 tokenC = IERC20(_token);
        require(tokenC.balanceOf(address(this)) >= _amount, 'not enough token');

        tokenC.universalApprove(address(cToken), _amount);
        cToken.repayBorrow(_amount);
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Get total debt balance & fee for an asset
     * @param _token Token address of the debt.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipient Address whose balance we get.
     */
    function borrowBalanceOf(address _token, address _recipient) public override returns (uint256) {
        CErc20Interface cToken = _getCToken(_token);
        return cToken.borrowBalanceCurrent(_recipient);
    }

    /**
     * @dev Get total collateral balance for an asset
     * @param _token Token address of the collateral.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipient Address whose balance we get.
     */
    function collateralBalanceOf(address _token, address _recipient) public override returns (uint256) {
        CErc20Interface cToken = _getCToken(_token);
        return cToken.balanceOfUnderlying(_recipient);
    }

    /**
     * @dev Mapping base token to cToken
     * @param _token Base token address.
     */
    function _getCToken(address _token) public pure override returns (CErc20Interface) {
        if (IERC20(_token).isETH()) {
            // oWETH
            return CErc20Interface(0xee1727f5074E747716637e1776B7F7C7133f16b1);
        }
        if (_token == 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035) {
            // USDC
            return CErc20Interface(0x68d9baA40394dA2e2c1ca05d30BF33F52823ee7B);
        }
        if (_token == 0x1E4a5963aBFD975d8c9021ce480b42188849D41d) {
            // USDT
            return CErc20Interface(0xad41C77d99E282267C1492cdEFe528D7d5044253);
        }
        if (_token == 0xa2036f0538221a77A3937F1379699f44945018d0) {
            // oMatic
            return CErc20Interface(0x8903Dc1f4736D2FcB90C1497AebBABA133DaAC76);
        }

        revert('Unsupported token');
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Enter compound market
     */
    function enterMarket(address cToken) internal {
        address[] memory markets = COMPTROLLER.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint i = 0; i < markets.length; i++) {
            if (markets[i] == cToken) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cToken;
            COMPTROLLER.enterMarkets(toEnter);
        }
    }
}
