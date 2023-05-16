// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import { IAaveV2Connector } from '../../interfaces/connectors/IAaveV2Connector.sol';
import { ILendingPool } from '../../interfaces/external/aave-v2/ILendingPool.sol';
import { IProtocolDataProvider } from '../../interfaces/external/aave-v2/IProtocolDataProvider.sol';
import { ILendingPoolAddressesProvider } from '../../interfaces/external/aave-v2/ILendingPoolAddressesProvider.sol';

import { UniversalERC20 } from '../../lib/UniversalERC20.sol';

contract AaveV2BaseConnector is IAaveV2Connector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    string public constant override name = 'AaveV2';

    /* ============ State Variables ============ */

    ILendingPoolAddressesProvider public immutable aaveProvider;
    IProtocolDataProvider public immutable aaveData;
    uint16 public immutable referralCode;

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _aaveProvider The address of the AddressesProvider contract
     * @param _aaveData The address of the DataProvider contract
     * @param _referralCode  The referral code number
     */
    constructor(ILendingPoolAddressesProvider _aaveProvider, IProtocolDataProvider _aaveData, uint16 _referralCode) {
        aaveProvider = _aaveProvider;
        aaveData = _aaveData;
        referralCode = _referralCode;
    }

    /* ============ External Functions ============ */

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @notice Deposit a token to Aave v2 for lending / collaterization.
     * @param _token The address of the token to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to deposit. (For max: `type(uint).max`)
     */
    function deposit(address _token, uint256 _amount) external payable override {
        ILendingPool aave = ILendingPool(aaveProvider.getLendingPool());

        IERC20 tokenC = IERC20(_token);

        _amount = _amount == type(uint).max ? tokenC.balanceOf(address(this)) : _amount;

        tokenC.universalApprove(address(aave), _amount);

        aave.deposit(_token, _amount, address(this), referralCode);

        if (!getIsCollateral(_token)) {
            aave.setUserUseReserveAsCollateral(_token, true);
        }
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @notice Withdraw deposited token from Aave v2
     * @param _token The address of the token to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to withdraw. (For max: `type(uint).max`)
     */
    function withdraw(address _token, uint256 _amount) external payable override {
        ILendingPool aave = ILendingPool(aaveProvider.getLendingPool());
        IERC20 tokenC = IERC20(_token);

        uint256 initialBal = tokenC.balanceOf(address(this));
        aave.withdraw(_token, _amount, address(this));
        uint256 finalBal = tokenC.balanceOf(address(this));

        _amount = finalBal - initialBal;
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @notice Borrow a token using Aave v2
     * @param _token The address of the token to borrow.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _rateMode The type of borrow debt. (For Stable: 1, Variable: 2)
     * @param _amount The amount of the token to borrow.
     */
    function borrow(address _token, uint256 _rateMode, uint256 _amount) external payable override {
        ILendingPool aave = ILendingPool(aaveProvider.getLendingPool());

        aave.borrow(_token, _amount, _rateMode, referralCode, address(this));
    }

    /**
     * @dev Payback borrowed ETH/ERC20_Token.
     * @notice Payback debt owed.
     * @param _token The address of the token to payback.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to payback. (For max: `type(uint).max`)
     * @param _rateMode The type of debt paying back. (For Stable: 1, Variable: 2)
     */
    function payback(address _token, uint256 _amount, uint256 _rateMode) external payable override {
        ILendingPool aave = ILendingPool(aaveProvider.getLendingPool());

        IERC20 tokenC = IERC20(_token);

        if (_amount == type(uint).max) {
            uint256 balance = tokenC.balanceOf(address(this));
            uint256 amountDebt = getPaybackBalance(_token, _rateMode, address(this));
            _amount = balance <= amountDebt ? balance : amountDebt;
        }

        tokenC.universalApprove(address(aave), _amount);

        aave.repay(_token, _amount, _rateMode, address(this));
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Get total debt balance & fee for an asset
     * @param _token token address of the debt.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _rateMode Borrow rate mode (Stable = 1, Variable = 2)
     * @param _user Address whose balance we get.
     */
    function getPaybackBalance(address _token, uint _rateMode, address _user) public view override returns (uint) {
        (, uint stableDebt, uint variableDebt, , , , , , ) = aaveData.getUserReserveData(_token, _user);
        return _rateMode == 1 ? stableDebt : variableDebt;
    }

    /**
     * @dev Get total collateral balance for an asset
     * @param _token token address of the collateral.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _user Address whose balance we get.
     */
    function getCollateralBalance(address _token, address _user) public view override returns (uint256 balance) {
        (balance, , , , , , , , ) = aaveData.getUserReserveData(_token, _user);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Checks if collateral is enabled for an asset
     * @param _token token address of the asset.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     */
    function getIsCollateral(address _token) internal view returns (bool IsCollateral) {
        (, , , , , , , , IsCollateral) = aaveData.getUserReserveData(_token, address(this));
    }
}
