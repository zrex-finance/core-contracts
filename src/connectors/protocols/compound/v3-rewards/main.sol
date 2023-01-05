// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Compound.
 * @dev Rewards.
 */

import { TokenInterface } from "../../../common/interfaces.sol";
import { Stores } from "../../../common/stores.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

abstract contract CompoundV3RewardsResolver is Events, Helpers {
	/**
	 * @dev Claim rewards and interests accrued in supplied/borrowed base asset.
	 * @notice Claim rewards and interests accrued.
	 * @param market The address of the market.
	 */
	function claimRewards(
		address market
	) public returns (string memory eventName_, bytes memory eventParam_) {
		uint256 rewardsOwed = cometRewards.getRewardOwed(market, address(this)).owed;
		cometRewards.claim(market, address(this), true);

		eventName_ = "LogRewardsClaimed(address,address,uint256)";
		eventParam_ = abi.encode(market, address(this), rewardsOwed);
	}

	/**
	 * @dev Claim rewards and interests accrued in supplied/borrowed base asset.
	 * @notice Claim rewards and interests accrued and transfer to dest address.
	 * @param market The address of the market.
	 * @param owner The account of which the rewards are to be claimed.
	 * @param to The account where to transfer the claimed rewards.
	 */
	function claimRewardsOnBehalfOf(
		address market,
		address owner,
		address to
	) public returns (string memory eventName_, bytes memory eventParam_) {
		//in reward token decimals
		uint256 rewardsOwed = cometRewards.getRewardOwed(market, owner).owed;
		cometRewards.claimTo(market, owner, to, true);

		eventName_ = "LogRewardsClaimedOnBehalf(address,address,address,uint256)";
		eventParam_ = abi.encode(
			market,
			owner,
			to,
			rewardsOwed
		);
	}
}

contract ConnectV2CompoundV3Rewards is CompoundV3RewardsResolver {
	string public name = "CompoundV3Rewards-v1.0";
}
