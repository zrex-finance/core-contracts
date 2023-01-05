// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interface.sol";
import { Basic } from "../../../common/base.sol";

contract Helpers is Basic {

    /**
     * @dev Euler Incentives Distributor
     */
    IEulerDistributor internal constant eulerDistribute = IEulerDistributor(0xd524E29E3BAF5BB085403Ca5665301E94387A7e2);

}
