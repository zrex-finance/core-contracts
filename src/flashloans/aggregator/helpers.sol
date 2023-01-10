// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./variables.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Helper is Variables {
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

    function compoundSupply(address[] memory _tokens, uint256[] memory _amounts)
        internal
    {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        address[] memory cTokens_ = new address[](length_);
        for (uint256 i = 0; i < length_; i++) {
            if (_tokens[i] == address(wethToken)) {
                wethToken.withdraw(_amounts[i]);
                CEthInterface cEth_ = CEthInterface(cethTokenAddr);
                cEth_.mint{value: _amounts[i]}();
                cTokens_[i] = cethTokenAddr;
            } else {
                CTokenInterface cToken_ = CTokenInterface(
                    tokenToCToken[_tokens[i]]
                );
                // Approved already in addTokenToctoken function
                require(cToken_.mint(_amounts[i]) == 0, "mint failed");
                cTokens_[i] = tokenToCToken[_tokens[i]];
            }
        }
    }

    function compoundBorrow(address[] memory _tokens, uint256[] memory _amounts)
        internal
    {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            if (_tokens[i] == address(wethToken)) {
                CEthInterface cEth = CEthInterface(cethTokenAddr);
                require(cEth.borrow(_amounts[i]) == 0, "borrow failed");
                wethToken.deposit{value: _amounts[i]}();
            } else {
                CTokenInterface cToken = CTokenInterface(
                    tokenToCToken[_tokens[i]]
                );
                require(cToken.borrow(_amounts[i]) == 0, "borrow failed");
            }
        }
    }

    function compoundPayback(
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            if (_tokens[i] == address(wethToken)) {
                wethToken.withdraw(_amounts[i]);
                CEthInterface cToken = CEthInterface(cethTokenAddr);
                cToken.repayBorrow{value: _amounts[i]}();
            } else {
                CTokenInterface cToken = CTokenInterface(
                    tokenToCToken[_tokens[i]]
                );
                // Approved already in addTokenToctoken function
                require(cToken.repayBorrow(_amounts[i]) == 0, "repay failed");
            }
        }
    }

    function compoundWithdraw(
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            if (_tokens[i] == address(wethToken)) {
                CEthInterface cEth_ = CEthInterface(cethTokenAddr);
                require(
                    cEth_.redeemUnderlying(_amounts[i]) == 0,
                    "redeem failed"
                );
                wethToken.deposit{value: _amounts[i]}();
            } else {
                CTokenInterface cToken_ = CTokenInterface(
                    tokenToCToken[_tokens[i]]
                );
                require(
                    cToken_.redeemUnderlying(_amounts[i]) == 0,
                    "redeem failed"
                );
            }
        }
    }

    function aaveSupply(address[] memory _tokens, uint256[] memory _amounts)
        internal
    {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            approve(_tokens[i], address(aaveLending), _amounts[i]);
            aaveLending.deposit(_tokens[i], _amounts[i], address(this), 3228);
            aaveLending.setUserUseReserveAsCollateral(_tokens[i], true);
        }
    }

    function aaveBorrow(address[] memory _tokens, uint256[] memory _amounts)
        internal
    {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            aaveLending.borrow(_tokens[i], _amounts[i], 2, 3228, address(this));
        }
    }

    function aavePayback(address[] memory _tokens, uint256[] memory _amounts)
        internal
    {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            approve(_tokens[i], address(aaveLending), _amounts[i]);
            aaveLending.repay(_tokens[i], _amounts[i], 2, address(this));
        }
    }

    function aaveWithdraw(address[] memory _tokens, uint256[] memory _amounts)
        internal
    {
        uint256 length_ = _tokens.length;
        require(_amounts.length == length_, "array-lengths-not-same");
        for (uint256 i = 0; i < length_; i++) {
            aaveLending.withdraw(_tokens[i], _amounts[i], address(this));
        }
    }

    function calculateFeeBPS(uint256 _route, address account_)
        public
        view
        returns (uint256 BPS_)
    {
        if (_route == 1) {
            BPS_ = aaveLending.FLASHLOAN_PREMIUM_TOTAL();
        } else if (_route == 2 || _route == 3 || _route == 4) {
            BPS_ = (makerLending.toll()) / (10**14);
        } else if (_route == 5 || _route == 6 || _route == 7) {
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

        if (!isWhitelisted[account_] && BPS_ < FeeBPS) {
            BPS_ = FeeBPS;
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

    function getWEthBorrowAmount() internal view returns (uint256) {
        uint256 amount_ = wethToken.balanceOf(address(balancerLending));
        return (amount_ * wethBorrowAmountPercentage) / 100;
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
