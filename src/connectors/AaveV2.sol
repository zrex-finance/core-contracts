// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { IAave, IAaveLendingPoolProvider, IAaveDataProvider } from "./interfaces/AaveV2.sol";

contract AaveV2Connector {
    using UniversalERC20 for IERC20;

    IAaveLendingPoolProvider internal constant aaveProvider =
        IAaveLendingPoolProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IAaveDataProvider internal constant aaveData = IAaveDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    uint16 internal constant referralCode = 0;

    string public constant name = "AaveV2";

    function deposit(address token, uint256 amount) external payable {
        IAave aave = IAave(aaveProvider.getLendingPool());

        IERC20 tokenC = IERC20(token);

        amount = amount == type(uint).max ? tokenC.balanceOf(address(this)) : amount;

        tokenC.universalApprove(address(aave), amount);

        aave.deposit(token, amount, address(this), referralCode);

        if (!getIsColl(token)) {
            aave.setUserUseReserveAsCollateral(token, true);
        }
    }

    function withdraw(address token, uint256 amount) external payable {
        IAave aave = IAave(aaveProvider.getLendingPool());
        IERC20 tokenC = IERC20(token);

        uint256 initialBal = tokenC.balanceOf(address(this));
        aave.withdraw(token, amount, address(this));
        uint256 finalBal = tokenC.balanceOf(address(this));

        amount = finalBal - initialBal;
    }

    function borrow(address token, uint256 rateMode, uint256 amount) external payable {
        IAave aave = IAave(aaveProvider.getLendingPool());

        aave.borrow(token, amount, rateMode, referralCode, address(this));
    }

    function payback(address token, uint256 amount, uint256 rateMode) external payable {
        IAave aave = IAave(aaveProvider.getLendingPool());

        IERC20 tokenC = IERC20(token);

        if (amount == type(uint).max) {
            uint256 _amount = tokenC.balanceOf(address(this));
            uint256 _amountDebt = getPaybackBalance(token, rateMode, address(this));
            amount = _amount <= _amountDebt ? _amount : _amountDebt;
        }

        tokenC.universalApprove(address(aave), amount);

        aave.repay(token, amount, rateMode, address(this));
    }

    function getIsColl(address token) internal view returns (bool isCol) {
        (, , , , , , , , isCol) = aaveData.getUserReserveData(token, address(this));
    }

    function getPaybackBalance(address token, uint rateMode, address _user) public view returns (uint) {
        (, uint stableDebt, uint variableDebt, , , , , , ) = aaveData.getUserReserveData(token, _user);
        return rateMode == 1 ? stableDebt : variableDebt;
    }

    function getCollateralBalance(address token, address _user) public view returns (uint256 bal) {
        (bal, , , , , , , , ) = aaveData.getUserReserveData(token, _user);
    }
}
