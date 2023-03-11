// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { IAave, IDToken, IAavePoolProvider, IAaveDataProvider } from "./interfaces/AaveV3.sol";

contract AaveV3Connector {
    using UniversalERC20 for IERC20;

    IAavePoolProvider internal constant aaveProvider = IAavePoolProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);

    IAaveDataProvider internal constant aaveData = IAaveDataProvider(0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3);

    uint16 internal constant referralCode = 0;

    string public constant name = "AaveV3";

    function deposit(address token, uint256 amount) external payable {
        IAave aave = IAave(aaveProvider.getPool());

        IERC20 tokenC = IERC20(token);

        amount = amount == type(uint256).max ? tokenC.balanceOf(address(this)) : amount;

        tokenC.universalApprove(address(aave), amount);

        aave.supply(token, amount, address(this), referralCode);

        if (!getIsColl(token)) {
            aave.setUserUseReserveAsCollateral(token, true);
        }
    }

    function withdraw(address token, uint256 amount) external payable {
        IAave aave = IAave(aaveProvider.getPool());

        IERC20 tokenC = IERC20(token);

        uint256 initialBalance = tokenC.balanceOf(address(this));
        aave.withdraw(token, amount, address(this));
        uint256 finalBalance = tokenC.balanceOf(address(this));

        amount = finalBalance - initialBalance;
    }

    function borrow(address token, uint256 rateMode, uint256 amount) external payable {
        IAave aave = IAave(aaveProvider.getPool());

        aave.borrow(token, amount, rateMode, referralCode, address(this));
    }

    function payback(address token, uint256 amount, uint256 rateMode) external payable {
        IAave aave = IAave(aaveProvider.getPool());

        IERC20 tokenC = IERC20(token);

        amount = amount == type(uint256).max ? getPaybackBalance(token, address(this), rateMode) : amount;

        tokenC.universalApprove(address(aave), amount);
        aave.repay(token, amount, rateMode, address(this));
    }

    function getIsColl(address token) internal view returns (bool isCol) {
        (, , , , , , , , isCol) = aaveData.getUserReserveData(token, address(this));
    }

    function getPaybackBalance(address token, address recipeint, uint256 rateMode) public view returns (uint256) {
        (, uint256 stableDebt, uint256 variableDebt, , , , , , ) = aaveData.getUserReserveData(token, recipeint);
        return rateMode == 1 ? stableDebt : variableDebt;
    }

    function getCollateralBalance(address token, address recipeint) public view returns (uint256 bal) {
        (bal, , , , , , , , ) = aaveData.getUserReserveData(token, recipeint);
    }
}
