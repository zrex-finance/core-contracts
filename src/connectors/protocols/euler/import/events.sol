// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Events {
	event LogEulerImport(
		address user,
		uint256 sourceId,
		uint256 targetId,
		address[] supplyTokens,
		uint256[] supplyAmounts,
		address[] borrowTokens,
		uint256[] borrowAmounts,
		bool[] enterMarket
	);
}
