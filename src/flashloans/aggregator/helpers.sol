// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TokenInterface } from "../../connectors/common/interfaces.sol";

import "./variables.sol";

contract FlashAggregatorHelper is Variables {
    using SafeERC20 for IERC20;

    function approve(
        address token_,
        address spender_,
        uint256 amount_
    ) internal {
        TokenInterface tokenContract_ = TokenInterface(token_);
        try tokenContract_.approve(spender_, amount_) {} catch {
            IERC20 token = IERC20(token_);
            token.safeApprove(spender_, 0);
            token.safeApprove(spender_, amount_);
        }
    }

    function safeApprove(
        FlashloanVariables memory _loanVariables,
        uint256[] memory _fees,
        address _receiver
    ) internal {
        uint256 length_ = _loanVariables._tokens.length;
        require(
            length_ == _loanVariables._amounts.length,
            "Lengths of parameters not same"
        );
        require(length_ == _fees.length, "Lengths of parameters not same");
        for (uint256 i = 0; i < length_; i++) {
            approve(
                _loanVariables._tokens[i],
                _receiver,
                _loanVariables._amounts[i] + _fees[i]
            );
        }
    }

    function safeTransfer(
        FlashloanVariables memory _loanVariables,
        address _receiver
    ) internal {
        uint256 length_ = _loanVariables._tokens.length;
        require(
            length_ == _loanVariables._amounts.length,
            "Lengths of parameters not same"
        );
        for (uint256 i = 0; i < length_; i++) {
            IERC20 token = IERC20(_loanVariables._tokens[i]);
            token.safeTransfer(_receiver, _loanVariables._amounts[i]);
        }
    }

    function safeTransferWithFee(
        FlashloanVariables memory _loanVariables,
        uint256[] memory _fees,
        address _receiver
    ) internal {
        uint256 length_ = _loanVariables._tokens.length;
        require(
            length_ == _loanVariables._amounts.length,
            "Lengths of parameters not same"
        );
        require(length_ == _fees.length, "Lengths of parameters not same");
        for (uint256 i = 0; i < length_; i++) {
            IERC20 token = IERC20(_loanVariables._tokens[i]);
            token.safeTransfer(
                _receiver,
                _loanVariables._amounts[i] + _fees[i]
            );
        }
    }

    function calculateBalances(address[] memory _tokens, address _account)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 _length = _tokens.length;
        uint256[] memory balances_ = new uint256[](_length);
        for (uint256 i = 0; i < _length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            balances_[i] = token.balanceOf(_account);
        }
        return balances_;
    }

    function validateFlashloan(FlashloanVariables memory _loanVariables)
        internal
        pure
    {
        for (uint256 i = 0; i < _loanVariables._iniBals.length; i++) {
            require(
                _loanVariables._iniBals[i] +
                    _loanVariables._fees[i] <=
                    _loanVariables._finBals[i],
                "amount-paid-less"
            );
        }
    }

    function validateTokens(address[] memory _tokens) internal pure {
        for (uint256 i = 0; i < _tokens.length - 1; i++) {
            require(_tokens[i] != _tokens[i + 1], "non-unique-tokens");
        }
    }

    function calculateFeeBPS(uint256 _route)
        public
        view
        returns (uint256 BPS_)
    {
        if (_route == 1) {
            BPS_ = aaveLending.FLASHLOAN_PREMIUM_TOTAL();
        } else if (_route == 2) {
            BPS_ = (makerLending.toll()) / (10**14);
        } else if (_route == 3) {
            BPS_ =
                (
                    balancerLending
                        .getProtocolFeesCollector()
                        .getFlashLoanFeePercentage()
                ) *
                100;
        } else {
            revert("Invalid source");
        }
    }

    function calculateFees(uint256[] memory _amounts, uint256 _BPS)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 length_ = _amounts.length;
        uint256[] memory fees = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            fees[i] = (_amounts[i] * _BPS) / (10**4);
        }
        return fees;
    }

    function bubbleSort(address[] memory _tokens, uint256[] memory _amounts)
        internal
        pure
        returns (address[] memory, uint256[] memory)
    {
        for (uint256 i = 0; i < _tokens.length - 1; i++) {
            for (uint256 j = 0; j < _tokens.length - i - 1; j++) {
                if (_tokens[j] > _tokens[j + 1]) {
                    (
                        _tokens[j],
                        _tokens[j + 1],
                        _amounts[j],
                        _amounts[j + 1]
                    ) = (
                        _tokens[j + 1],
                        _tokens[j],
                        _amounts[j + 1],
                        _amounts[j]
                    );
                }
            }
        }
        return (_tokens, _amounts);
    }

    modifier verifyDataHash(bytes memory data_) {
        bytes32 dataHash_ = keccak256(data_);
        require(
            dataHash_ == dataHash && dataHash_ != bytes32(0),
            "invalid-data-hash"
        );
        require(status == 2, "already-entered");
        dataHash = bytes32(0);
        _;
        status = 1;
    }

    modifier reentrancy() {
        require(status == 1, "already-entered");
        status = 2;
        _;
        require(status == 1, "already-entered");
    }
}
