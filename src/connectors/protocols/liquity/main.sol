// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Liquity.
 * @dev Lending & Borrowing.
 */
import {
    BorrowerOperationsLike,
    TroveManagerLike,
    StabilityPoolLike,
    StakingLike,
    CollateralSurplusLike,
    LqtyTokenLike
} from "./interface.sol";
import { Stores } from "../../common/stores.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

abstract contract LiquityResolver is Events, Helpers {


    /* Begin: Trove */

    /**
     * @dev Deposit native ETH and borrow LUSD
     * @notice Opens a Trove by depositing ETH and borrowing LUSD
     * @param depositAmount The amount of ETH to deposit
     * @param maxFeePercentage The maximum borrow fee that this transaction should permit 
     * @param borrowAmount The amount of LUSD to borrow
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
    function open(
        uint depositAmount,
        uint maxFeePercentage,
        uint borrowAmount,
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        depositAmount = depositAmount == uint(-1) ? address(this).balance : depositAmount;

        borrowerOperations.openTrove{value: depositAmount}(
            maxFeePercentage,
            borrowAmount,
            upperHint,
            lowerHint
        );

        _eventName = "LogOpen(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(address(this), maxFeePercentage, depositAmount, borrowAmount);
    }

    /**
     * @dev Repay LUSD debt from the DSA account's LUSD balance, and withdraw ETH to DSA
     * @notice Closes a Trove by repaying LUSD debt
    */
    function close() external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint collateral = troveManager.getTroveColl(address(this));
        borrowerOperations.closeTrove();

         _eventName = "LogClose(address)";
        _eventParam = abi.encode(address(this));
    }

    /**
     * @dev Deposit ETH to Trove
     * @notice Increase Trove collateral (collateral Top up)
     * @param amount Amount of ETH to deposit into Trove
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
    function deposit(
        uint amount,
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam)  {
        amount = amount == uint(-1) ? address(this).balance : amount;

        borrowerOperations.addColl{value: amount}(upperHint, lowerHint);

        _eventName = "LogDeposit(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }

    /**
     * @dev Withdraw ETH from Trove
     * @notice Move Trove collateral from Trove to DSA
     * @param amount Amount of ETH to move from Trove to DSA
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
   function withdraw(
        uint amount,
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam)  {
        amount = amount == uint(-1) ? troveManager.getTroveColl(address(this)) : amount;

        borrowerOperations.withdrawColl(amount, upperHint, lowerHint);

        _eventName = "LogWithdraw(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }
    
    /**
     * @dev Mints LUSD tokens
     * @notice Borrow LUSD via an existing Trove
     * @param maxFeePercentage The maximum borrow fee that this transaction should permit 
     * @param amount Amount of LUSD to borrow
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
    function borrow(
        uint maxFeePercentage,
        uint amount,
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam)  {
        borrowerOperations.withdrawLUSD(maxFeePercentage, amount, upperHint, lowerHint);

        _eventName = "LogBorrow(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }

    /**
     * @dev Send LUSD to repay debt
     * @notice Repay LUSD Trove debt
     * @param amount Amount of LUSD to repay
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
    function repay(
        uint amount,
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam)  {
        if (amount == uint(-1)) {
            uint _lusdBal = lusdToken.balanceOf(address(this));
            uint _totalDebt = troveManager.getTroveDebt(address(this));
            amount = _lusdBal > _totalDebt ? _totalDebt : _lusdBal;
        }

        borrowerOperations.repayLUSD(amount, upperHint, lowerHint);

        _eventName = "LogRepay(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }

    /**
     * @dev Increase or decrease Trove ETH collateral and LUSD debt in one transaction
     * @notice Adjust Trove debt and/or collateral
     * @param maxFeePercentage The maximum borrow fee that this transaction should permit 
     * @param withdrawAmount Amount of ETH to withdraw
     * @param depositAmount Amount of ETH to deposit
     * @param borrowAmount Amount of LUSD to borrow
     * @param repayAmount Amount of LUSD to repay
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
    function adjust(
        uint maxFeePercentage,
        uint depositAmount,
        uint withdrawAmount,
        uint borrowAmount,
        uint repayAmount,
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        AdjustTrove memory adjustTrove;

        adjustTrove.maxFeePercentage = maxFeePercentage;

        adjustTrove.depositAmount = depositAmount == uint(-1) ? address(this).balance : depositAmount;

        adjustTrove.withdrawAmount = withdrawAmount == uint(-1) ? troveManager.getTroveColl(address(this)) : withdrawAmount;

        if (repayAmount == uint(-1)) {
            uint _lusdBal = lusdToken.balanceOf(address(this));
            uint _totalDebt = troveManager.getTroveDebt(address(this));
            repayAmount = _lusdBal > _totalDebt ? _totalDebt : _lusdBal;
        }

        adjustTrove.isBorrow = borrowAmount > 0;
        adjustTrove.lusdChange = adjustTrove.isBorrow ? borrowAmount : repayAmount;
        
        borrowerOperations.adjustTrove{value: adjustTrove.depositAmount}(
            adjustTrove.maxFeePercentage,
            adjustTrove.withdrawAmount,
            adjustTrove.lusdChange,
            adjustTrove.isBorrow,
            upperHint,
            lowerHint
        );

        _eventName = "LogAdjust(address,uint256,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(address(this), maxFeePercentage, adjustTrove.depositAmount, adjustTrove.withdrawAmount, borrowAmount, repayAmount);
    }

    /**
     * @dev Withdraw remaining ETH balance from user's redeemed Trove to their DSA
     * @notice Claim remaining collateral from Trove
    */
    function claimCollateralFromRedemption() external payable returns(string memory _eventName, bytes memory _eventParam) {
        uint amount = collateralSurplus.getCollateral(address(this));
        borrowerOperations.claimCollateral();

        _eventName = "LogClaimCollateralFromRedemption(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }
    /* End: Trove */

    /* Begin: Stability Pool */

    /**
     * @dev Deposit LUSD into Stability Pool
     * @notice Deposit LUSD into Stability Pool
     * @param amount Amount of LUSD to deposit into Stability Pool
     * @param frontendTag Address of the frontend to make this deposit against (determines the kickback rate of rewards)
    */
    function stabilityDeposit(
        uint amount,
        address frontendTag
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        amount = amount == uint(-1) ? lusdToken.balanceOf(address(this)) : amount;

        uint ethGain = stabilityPool.getDepositorETHGain(address(this));
        uint lqtyBalanceBefore = lqtyToken.balanceOf(address(this));
        
        stabilityPool.provideToSP(amount, frontendTag);
        
        uint lqtyBalanceAfter = lqtyToken.balanceOf(address(this));
        uint lqtyGain = sub(lqtyBalanceAfter, lqtyBalanceBefore);

        _eventName = "LogStabilityDeposit(address,uint256,uint256,uint256,address)";
        _eventParam = abi.encode(address(this), amount, ethGain, lqtyGain, frontendTag);
    }

    /**
     * @dev Withdraw user deposited LUSD from Stability Pool
     * @notice Withdraw LUSD from Stability Pool
     * @param amount Amount of LUSD to withdraw from Stability Pool
    */
    function stabilityWithdraw(
        uint amount
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        amount = amount == uint(-1) ? stabilityPool.getCompoundedLUSDDeposit(address(this)) : amount;

        uint ethGain = stabilityPool.getDepositorETHGain(address(this));
        uint lqtyBalanceBefore = lqtyToken.balanceOf(address(this));
        
        stabilityPool.withdrawFromSP(amount);
        
        uint lqtyBalanceAfter = lqtyToken.balanceOf(address(this));
        uint lqtyGain = sub(lqtyBalanceAfter, lqtyBalanceBefore);

        _eventName = "LogStabilityWithdraw(address,uint256,uint256,uint25)";
        _eventParam = abi.encode(address(this), amount, ethGain, lqtyGain);
    }

    /**
     * @dev Increase Trove collateral by sending Stability Pool ETH gain to user's Trove
     * @notice Moves user's ETH gain from the Stability Pool into their Trove
     * @param upperHint Address of the Trove near the upper bound of where the user's Trove should now sit in the ordered Trove list
     * @param lowerHint Address of the Trove near the lower bound of where the user's Trove should now sit in the ordered Trove list
    */
    function stabilityMoveEthGainToTrove(
        address upperHint,
        address lowerHint
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint amount = stabilityPool.getDepositorETHGain(address(this));
        stabilityPool.withdrawETHGainToTrove(upperHint, lowerHint);
        _eventName = "LogStabilityMoveEthGainToTrove(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }
    /* End: Stability Pool */

    /* Begin: Staking */

    /**
     * @dev Sends LQTY tokens from user to Staking Pool
     * @notice Stake LQTY in Staking Pool
     * @param amount Amount of LQTY to stake
    */
    function stake(
        uint amount
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        amount = amount == uint(-1) ? lqtyToken.balanceOf(address(this)) : amount;

        uint ethGain = staking.getPendingETHGain(address(this));
        uint lusdGain = staking.getPendingLUSDGain(address(this));

        staking.stake(amount);

        _eventName = "LogStake(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }

    /**
     * @dev Sends LQTY tokens from Staking Pool to user
     * @notice Unstake LQTY in Staking Pool
     * @param amount Amount of LQTY to unstake
    */
    function unstake(
        uint amount
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        amount = amount == uint(-1) ? staking.stakes(address(this)) : amount;

        uint ethGain = staking.getPendingETHGain(address(this));
        uint lusdGain = staking.getPendingLUSDGain(address(this));

        staking.unstake(amount);

        _eventName = "LogUnstake(address,uint256)";
        _eventParam = abi.encode(address(this), amount);
    }

    /**
     * @dev Sends ETH and LUSD gains from Staking to user
     * @notice Claim ETH and LUSD gains from Staking
    */
    function claimStakingGains() external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint ethGain = staking.getPendingETHGain(address(this));
        uint lusdGain = staking.getPendingLUSDGain(address(this));

        // Gains are claimed when a user's stake is adjusted, so we unstake 0 to trigger the claim
        staking.unstake(0);
        
        _eventName = "LogClaimStakingGains(address,uint256,uint256)";
        _eventParam = abi.encode(address(this), ethGain, lusdGain);
    }
    /* End: Staking */

}

contract ConnectV2Liquity is LiquityResolver {
    string public name = "Liquity-v1";
}
