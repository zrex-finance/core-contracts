// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./helpers.sol";
import "./events.sol";

/**
 * @title Euler Rewards.
 * @dev Claim Euler rewards.
 */

contract EulerIncentives is Helpers, Events {

    /**
     * @dev Claim Pending Rewards.
     * @notice Claim Pending Rewards from Euler incentives contract.
     * @param user Address that should receive tokens.
     * @param token Address of token being claimed (ie EUL)
     * @param amt The amount of reward to claim.
     * @param proof Merkle proof that validates this claim.
    */
    function claim(
        address user,
        address token,
        uint256 amt,
        bytes32[] memory proof
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        require(proof.length > 0, "proofs-empty");

        eulerDistribute.claim(user, token, amt, proof, address(0));

        _eventName = "LogClaimed(address,address,uint256)";
        _eventParam = abi.encode(user, token, amt);
    }
}

contract ConnectV2EulerIncentives is EulerIncentives {
    string public constant name = "Euler-Incentives-v1";
}
