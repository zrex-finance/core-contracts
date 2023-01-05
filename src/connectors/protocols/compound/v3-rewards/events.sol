// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Events {
	event LogRewardsClaimed(
		address indexed market,
		address indexed account,
		uint256 indexed rewardsClaimed,
		uint256 setId
	);

	event LogRewardsClaimedOnBehalf(
		address indexed market,
		address indexed owner,
		address to,
		uint256 indexed rewardsClaimed,
		uint256 setId
	);
}
