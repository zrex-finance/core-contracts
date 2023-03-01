// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Basic } from "../../../common/base.sol";
import { IAaveLendingPoolProvider, IAaveDataProvider } from "./interface.sol";

abstract contract AaveHelpers is Basic {
    
    IAaveLendingPoolProvider constant internal aaveProvider = 
IAaveLendingPoolProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IAaveDataProvider constant internal aaveData = 
        IAaveDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    uint16 constant internal referralCode = 0;

    function getIsColl(address token) internal view returns (bool isCol) {
        (, , , , , , , , isCol) = aaveData.getUserReserveData(token, address(this));
    }

    function getPaybackBalance(address token, uint rateMode) internal view returns (uint) {
        (, uint stableDebt, uint variableDebt, , , , , , ) = aaveData.getUserReserveData(token, address(this));
        return rateMode == 1 ? stableDebt : variableDebt;
    }

    function getPaybackBalance(address token, uint rateMode, address _user) public view returns (uint) {
        (, uint stableDebt, uint variableDebt, , , , , , ) = aaveData.getUserReserveData(token, _user);
        return rateMode == 1 ? stableDebt : variableDebt;
    }

	function getOnBehalfOfPaybackBalance(address token, uint256 rateMode, address onBehalfOf)
		internal
		view
		returns (uint256)
	{
		(, uint256 stableDebt, uint256 variableDebt, , , , , , ) = aaveData
			.getUserReserveData(token, onBehalfOf);
		return rateMode == 1 ? stableDebt : variableDebt;
	}

    function getCollateralBalance(address token) internal view returns (uint bal) {
        (bal, , , , , , , ,) = aaveData.getUserReserveData(token, address(this));
    }

    function getCollateralBalance(address token, address _user) public view returns (uint256 bal) {
        (bal, , , , , , , ,) = aaveData.getUserReserveData(token, _user);
    }
}
