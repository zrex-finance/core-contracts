// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./helpers.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FlashAggregator is Helper {
    using SafeERC20 for IERC20;

    event LogFlashloan(
        address indexed account,
        uint256 indexed route,
        address[] tokens,
        uint256[] amounts
    );
    
    receive() external payable {}

    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), "not-same-sender");
        require(msg.sender == address(aaveLending), "not-aave-sender");

        FlashloanVariables memory loanVariables_;

        (address sender_, bytes memory data_) = abi.decode(
            _data,
            (address, bytes)
        );

        loanVariables_._tokens = _assets;
        loanVariables_._amounts = _amounts;
        loanVariables_._fees = calculateFees(
            _amounts,
            calculateFeeBPS(1, sender_)
        );
        loanVariables_._iniBals = calculateBalances(
            _assets,
            address(this)
        );

        safeApprove(loanVariables_, _premiums, address(aaveLending));
        safeTransfer(loanVariables_, sender_);

        FlashReceiverInterface(sender_).executeOperation(
                _assets,
                _amounts,
                loanVariables_._fees,
                sender_,
                data_
            );

        loanVariables_._finBals = calculateBalances(
            _assets,
            address(this)
        );
        validateFlashloan(loanVariables_);

        return true;
    }


    function onFlashLoan(
        address _initiator,
        address,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _data
    ) external verifyDataHash(_data) returns (bytes32) {
        require(_initiator == address(this), "not-same-sender");
        require(msg.sender == address(makerLending), "not-maker-sender");

        FlashloanVariables memory loanVariables_;

        (
            uint256 route_,
            address[] memory tokens_,
            uint256[] memory amounts_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data, (uint256, address[], uint256[], address, bytes));

        loanVariables_._tokens = tokens_;
        loanVariables_._amounts = amounts_;
        loanVariables_._iniBals = calculateBalances(
            tokens_,
            address(this)
        );
        loanVariables_._fees = calculateFees(
            amounts_,
            calculateFeeBPS(route_, sender_)
        );

        if (route_ == 2) {
            safeTransfer(loanVariables_, sender_);

            FlashReceiverInterface(sender_).executeOperation(
                    tokens_,
                    amounts_,
                    loanVariables_._fees,
                    sender_,
                    data_
                );
        } else if (route_ == 3 || route_ == 4) {
            require(_fee == 0, "flash-DAI-fee-not-0");

            address[] memory _daiTokenList = new address[](1);
            uint256[] memory _daiTokenAmountsList = new uint256[](1);
            _daiTokenList[0] = daiTokenAddr;
            _daiTokenAmountsList[0] = _amount;

            if (route_ == 3) {
                compoundSupply(_daiTokenList, _daiTokenAmountsList);
                compoundBorrow(tokens_, amounts_);
            } else {
                aaveSupply(_daiTokenList, _daiTokenAmountsList);
                aaveBorrow(tokens_, amounts_);
            }

            safeTransfer(loanVariables_, sender_);

            FlashReceiverInterface(sender_).executeOperation(
                    tokens_,
                    amounts_,
                    loanVariables_._fees,
                    sender_,
                    data_
                );

            if (route_ == 3) {
                compoundPayback(tokens_, amounts_);
                compoundWithdraw(_daiTokenList, _daiTokenAmountsList);
            } else {
                aavePayback(tokens_, amounts_);
                aaveWithdraw(_daiTokenList, _daiTokenAmountsList);
            }
        } else {
            revert("wrong-route");
        }

        loanVariables_._finBals = calculateBalances(
            tokens_,
            address(this)
        );
        validateFlashloan(loanVariables_);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory _amounts,
        uint256[] memory _fees,
        bytes memory _data
    ) external verifyDataHash(_data) {
        require(msg.sender == address(balancerLending), "not-balancer-sender");

        FlashloanVariables memory loanVariables_;

        (
            uint256 route_,
            address[] memory tokens_,
            uint256[] memory amounts_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data, (uint256, address[], uint256[], address, bytes));

        loanVariables_._tokens = tokens_;
        loanVariables_._amounts = amounts_;
        loanVariables_._iniBals = calculateBalances(
            tokens_,
            address(this)
        );
        loanVariables_._fees = calculateFees(
            amounts_,
            calculateFeeBPS(route_, sender_)
        );

        if (route_ == 5) {
            if (tokens_[0] == stEthTokenAddr) {
                wstEthToken.unwrap(_amounts[0]);
            }
            safeTransfer(loanVariables_, sender_);
            FlashReceiverInterface(sender_).executeOperation(
                    tokens_,
                    amounts_,
                    loanVariables_._fees,
                    sender_,
                    data_
                );
            if (tokens_[0] == stEthTokenAddr) {
                wstEthToken.wrap(amounts_[0]);
            }

            loanVariables_._finBals = calculateBalances(
                tokens_,
                address(this)
            );
            if (tokens_[0] == stEthTokenAddr) {
                // adding 10 wei to avoid any possible decimal errors in final calculations
                loanVariables_._finBals[0] =
                    loanVariables_._finBals[0] +
                    10;
                loanVariables_._tokens[0] = address(wstEthToken);
                loanVariables_._amounts[0] = _amounts[0];
            }
            validateFlashloan(loanVariables_);
            safeTransferWithFee(
                loanVariables_,
                _fees,
                address(balancerLending)
            );
        } else if (route_ == 6 || route_ == 7) {
            require(_fees[0] == 0, "flash-ETH-fee-not-0");

            address[] memory wEthTokenList = new address[](1);
            wEthTokenList[0] = address(wethToken);

            if (route_ == 6) {
                compoundSupply(wEthTokenList, _amounts);
                compoundBorrow(tokens_, amounts_);
            } else {
                aaveSupply(wEthTokenList, _amounts);
                aaveBorrow(tokens_, amounts_);
            }

            safeTransfer(loanVariables_, sender_);

            FlashReceiverInterface(sender_).executeOperation(
                    tokens_,
                    amounts_,
                    loanVariables_._fees,
                    sender_,
                    data_
                );

            if (route_ == 6) {
                compoundPayback(tokens_, amounts_);
                compoundWithdraw(wEthTokenList, _amounts);
            } else {
                aavePayback(tokens_, amounts_);
                aaveWithdraw(wEthTokenList, _amounts);
            }
            loanVariables_._finBals = calculateBalances(
                tokens_,
                address(this)
            );
            validateFlashloan(loanVariables_);
            loanVariables_._tokens = wEthTokenList;
            loanVariables_._amounts = _amounts;
            safeTransferWithFee(
                loanVariables_,
                _fees,
                address(balancerLending)
            );
        } else {
            revert("wrong-route");
        }
    }

    function routeAave(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(msg.sender, _data);
        uint256 length_ = _tokens.length;
        uint256[] memory _modes = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            _modes[i] = 0;
        }
        dataHash = bytes32(keccak256(data_));
        aaveLending.flashLoan(
            address(this),
            _tokens,
            _amounts,
            _modes,
            address(0),
            data_,
            3228
        );
    }

    function routeMaker(
        address _token,
        uint256 _amount,
        bytes memory _data
    ) internal {
        address[] memory tokens_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);
        tokens_[0] = _token;
        amounts_[0] = _amount;
        bytes memory data_ = abi.encode(
            2,
            tokens_,
            amounts_,
            msg.sender,
            _data
        );
        dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            _token,
            _amount,
            data_
        );
    }

    function routeMakerCompound(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(
            3,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            daiTokenAddr,
            daiBorrowAmount,
            data_
        );
    }

    function routeMakerAave(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(
            4,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            daiTokenAddr,
            daiBorrowAmount,
            data_
        );
    }

    function routeBalancer(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        uint256 length_ = _tokens.length;
        IERC20[] memory tokens_ = new IERC20[](length_);
        for (uint256 i = 0; i < length_; i++) {
            tokens_[i] = IERC20(_tokens[i]);
        }
        bytes memory data_ = abi.encode(
            5,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        dataHash = bytes32(keccak256(data_));
        if (_tokens[0] == stEthTokenAddr) {
            require(length_ == 1, "steth-length-should-be-1");
            tokens_[0] = IERC20(address(wstEthToken));
            _amounts[0] = wstEthToken.getWstETHByStETH(_amounts[0]);
        }
        balancerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            tokens_,
            _amounts,
            data_
        );
    }

    function routeBalancerCompound(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(
            6,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        IERC20[] memory wethTokenList_ = new IERC20[](1);
        uint256[] memory wethAmountList_ = new uint256[](1);
        wethTokenList_[0] = IERC20(wethToken);
        wethAmountList_[0] = getWEthBorrowAmount();
        dataHash = bytes32(keccak256(data_));
        balancerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            wethTokenList_,
            wethAmountList_,
            data_
        );
    }

    function routeBalancerAave(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(
            7,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        IERC20[] memory wethTokenList_ = new IERC20[](1);
        uint256[] memory wethAmountList_ = new uint256[](1);
        wethTokenList_[0] = wethToken;
        wethAmountList_[0] = getWEthBorrowAmount();
        dataHash = bytes32(keccak256(data_));
        balancerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            wethTokenList_,
            wethAmountList_,
            data_
        );
    }

    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _route,
        bytes calldata _data,
        bytes calldata 
    ) external reentrancy {
        require(_tokens.length == _amounts.length, "array-lengths-not-same");

        (_tokens, _amounts) = bubbleSort(_tokens, _amounts);
        validateTokens(_tokens);

        if (_route == 1) {
            routeAave(_tokens, _amounts, _data);
        } else if (_route == 2) {
            routeMaker(_tokens[0], _amounts[0], _data);
        } else if (_route == 3) {
            routeMakerCompound(_tokens, _amounts, _data);
        } else if (_route == 4) {
            routeMakerAave(_tokens, _amounts, _data);
        } else if (_route == 5) {
            routeBalancer(_tokens, _amounts, _data);
        } else if (_route == 6) {
            routeBalancerCompound(_tokens, _amounts, _data);
        } else if (_route == 7) {
            routeBalancerAave(_tokens, _amounts, _data);
        } else {
            revert("route-does-not-exist");
        }

        emit LogFlashloan(msg.sender, _route, _tokens, _amounts);
    }

    function getRoutes() public pure returns (uint16[] memory routes_) {
        routes_ = new uint16[](7);
        routes_[0] = 1;
        routes_[1] = 2;
        routes_[2] = 3;
        routes_[3] = 4;
        routes_[4] = 5;
        routes_[5] = 6;
        routes_[6] = 7;
    }

    function transferFeeToTreasury(address[] memory _tokens) public {
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token_ = IERC20(_tokens[i]);
            uint256 decimals_ = TokenInterface(_tokens[i]).decimals();
            uint256 amtToSub_ = decimals_ == 18 ? 1e10 : decimals_ > 12
                ? 10000
                : decimals_ > 7
                ? 100
                : 10;
            uint256 amtToTransfer_ = token_.balanceOf(address(this)) > amtToSub_
                ? (token_.balanceOf(address(this)) - amtToSub_)
                : 0;
            if (amtToTransfer_ > 0)
                token_.safeTransfer(treasuryAddr, amtToTransfer_);
        }
    }
}
