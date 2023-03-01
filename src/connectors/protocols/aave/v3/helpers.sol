// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Basic } from "../../../common/base.sol";
import { IAavePoolProvider, IAaveDataProvider } from "./interface.sol";

abstract contract Helpers is Basic {

	IAavePoolProvider internal constant aaveProvider =
		IAavePoolProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);

	IAaveDataProvider internal constant aaveData =
		IAaveDataProvider(0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3);

	uint16 internal constant referralCode = 0;

	function getIsColl(address token) internal view returns (bool isCol) {
		(, , , , , , , , isCol) = aaveData.getUserReserveData(token,address(this));
	}

	function getPaybackBalance(address token, uint256 rateMode) internal view returns (uint256){
		(, uint256 stableDebt, uint256 variableDebt, , , , , , ) = aaveData.getUserReserveData(token, address(this));
		return rateMode == 1 ? stableDebt : variableDebt;
	}

	function getOnBehalfOfPaybackBalance(address token, uint256 rateMode, address onBehalfOf)
		internal
		view
		returns (uint256)
	{
		(, uint256 stableDebt, uint256 variableDebt, , , , , , ) = aaveData.getUserReserveData(token, onBehalfOf);
		return rateMode == 1 ? stableDebt : variableDebt;
	}

	function getCollateralBalance(address token) internal view returns (uint256 bal) {
		(bal, , , , , , , , ) = aaveData.getUserReserveData(token,address(this));
	}

	function getDTokenAddr(address token, uint256 rateMode)	internal view returns(address dToken) {
		if (rateMode == 1) {
			(, dToken, ) = aaveData.getReserveTokensAddresses(token);
		} else {
			(, , dToken) = aaveData.getReserveTokensAddresses(token);
		}
	}
}
