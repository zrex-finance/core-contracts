// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { IAaveLending, IFlashReceiver, IBalancerLending, IERC3156FlashLender } from "./interfaces/FlashAggregator.sol";

contract FlashAggregator {
    using UniversalERC20 for IERC20;

    IAaveLending internal constant aaveLending = IAaveLending(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IERC3156FlashLender internal constant makerLending =
        IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
    IBalancerLending internal constant balancerLending = IBalancerLending(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint256 internal status;
    bytes32 internal dataHash;

    receive() external payable {}

    constructor() {
        require(status == 0, "cannot call again");
        status = 1;
    }

    modifier verifyDataHash(bytes memory data_) {
        bytes32 dataHash_ = keccak256(data_);
        require(dataHash_ == dataHash && dataHash_ != bytes32(0), "invalid-data-hash");
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

    /**
     * @notice Callback function for aave flashloan.
     */
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), "not same sender");
        require(msg.sender == address(aaveLending), "not aave sender");

        (uint256 route_, address sender_, bytes memory data_) = abi.decode(_data, (uint256, address, bytes));

        uint256[] memory _fees = calculateFees(_amounts, calculateFeeBPS(route_));
        uint256[] memory _initialBalances = calculateBalances(_assets, address(this));

        safeApprove(_assets, _amounts, _premiums, address(aaveLending));
        safeTransfer(_assets, _amounts, sender_);

        IFlashReceiver(sender_).executeOperation(_assets, _amounts, _fees, sender_, data_);

        uint256[] memory _finalBalances = calculateBalances(_assets, address(this));

        validateFlashloan(_initialBalances, _finalBalances, _fees);

        return true;
    }

    /**
     * @notice Fallback function for makerdao flashloan.
     */
    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external verifyDataHash(_data) returns (bytes32) {
        require(_initiator == address(this), "not same sender");
        require(msg.sender == address(makerLending), "not maker sender");

        (uint256 route_, address[] memory assets_, uint256[] memory amounts_, address sender_, bytes memory data_) = abi
            .decode(_data, (uint256, address[], uint256[], address, bytes));

        uint256[] memory _fees = calculateFees(amounts_, calculateFeeBPS(route_));
        uint256[] memory _initialBalances = calculateBalances(assets_, address(this));

        safeApprove(assets_, amounts_, _fees, address(makerLending));
        safeTransfer(assets_, amounts_, sender_);

        IFlashReceiver(sender_).executeOperation(assets_, amounts_, _fees, sender_, data_);
        uint256[] memory _finalBalances = calculateBalances(assets_, address(this));
        validateFlashloan(_initialBalances, _finalBalances, _fees);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /**
     * @notice Fallback function for balancer flashloan.
     */
    function receiveFlashLoan(
        address[] memory,
        uint256[] memory,
        uint256[] memory _fees,
        bytes memory _data
    ) external verifyDataHash(_data) {
        require(msg.sender == address(balancerLending), "not balancer sender");

        (uint256 route_, address[] memory assets_, uint256[] memory amounts_, address sender_, bytes memory data_) = abi
            .decode(_data, (uint256, address[], uint256[], address, bytes));

        uint256[] memory fees_ = calculateFees(amounts_, calculateFeeBPS(route_));
        uint256[] memory initialBalances_ = calculateBalances(assets_, address(this));

        safeTransfer(assets_, amounts_, sender_);
        IFlashReceiver(sender_).executeOperation(assets_, amounts_, fees_, sender_, data_);

        uint256[] memory _finalBalances = calculateBalances(assets_, address(this));

        validateFlashloan(initialBalances_, _finalBalances, fees_);
        safeTransferWithFee(assets_, amounts_, _fees, address(balancerLending));
    }

    function routeAave(address[] memory _tokens, uint256[] memory _amounts, bytes memory _data) internal {
        bytes memory data_ = abi.encode(1, msg.sender, _data);
        uint256 length_ = _tokens.length;
        uint256[] memory _modes = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            _modes[i] = 0;
        }
        dataHash = bytes32(keccak256(data_));
        aaveLending.flashLoan(address(this), _tokens, _amounts, _modes, address(0), data_, 0);
    }

    function routeMaker(address[] memory _tokens, uint256[] memory _amounts, bytes memory _data) internal {
        bytes memory data_ = abi.encode(2, _tokens, _amounts, msg.sender, _data);
        dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(IFlashReceiver(address(this)), _tokens[0], _amounts[0], data_);
    }

    function routeBalancer(address[] memory _tokens, uint256[] memory _amounts, bytes memory _data) internal {
        bytes memory data_ = abi.encode(3, _tokens, _amounts, msg.sender, _data);
        dataHash = bytes32(keccak256(data_));

        balancerLending.flashLoan(IFlashReceiver(address(this)), _tokens, _amounts, data_);
    }

    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _route,
        bytes calldata _data,
        bytes calldata
    ) external reentrancy {
        require(_tokens.length == _amounts.length, "array-lengths-not-same");

        validateTokens(_tokens);

        if (_route == 1) {
            routeAave(_tokens, _amounts, _data);
        } else if (_route == 2) {
            routeMaker(_tokens, _amounts, _data);
        } else if (_route == 3) {
            routeBalancer(_tokens, _amounts, _data);
        } else {
            revert("route-does-not-exist");
        }

        emit LogFlashloan(msg.sender, _route, _tokens, _amounts);
    }

    function getRoutes() public pure returns (uint16[] memory routes_) {
        routes_ = new uint16[](3);
        routes_[0] = 1;
        routes_[1] = 2;
        routes_[2] = 3;
    }

    function safeApprove(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _fees,
        address _receiver
    ) internal {
        uint256 length_ = _tokens.length;
        require(length_ == _amounts.length, "Lengths of parameters not same");
        require(length_ == _fees.length, "Lengths of parameters not same");

        for (uint256 i = 0; i < length_; i++) {
            IERC20(_tokens[i]).universalApprove(_receiver, _amounts[i] + _fees[i]);
        }
    }

    function safeTransfer(address[] memory _tokens, uint256[] memory _amounts, address _receiver) internal {
        uint256 length_ = _tokens.length;
        require(length_ == _amounts.length, "Lengths of parameters not same");

        for (uint256 i = 0; i < length_; i++) {
            IERC20(_tokens[i]).universalTransfer(_receiver, _amounts[i]);
        }
    }

    function safeTransferWithFee(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _fees,
        address _receiver
    ) internal {
        uint256 length_ = _tokens.length;
        require(length_ == _amounts.length, "Lengths of parameters not same");
        require(length_ == _fees.length, "Lengths of parameters not same");

        for (uint256 i = 0; i < length_; i++) {
            IERC20(_tokens[i]).universalTransfer(_receiver, _amounts[i] + _fees[i]);
        }
    }

    function calculateBalances(address[] memory _tokens, address _account) internal view returns (uint256[] memory) {
        uint256 _length = _tokens.length;
        uint256[] memory balances_ = new uint256[](_length);
        for (uint256 i = 0; i < _length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            balances_[i] = token.balanceOf(_account);
        }
        return balances_;
    }

    function validateFlashloan(
        uint256[] memory _initialBalances,
        uint256[] memory _finalBalances,
        uint256[] memory _fees
    ) internal pure {
        for (uint256 i = 0; i < _initialBalances.length; i++) {
            require(_initialBalances[i] + _fees[i] <= _finalBalances[i], "amount paid less");
        }
    }

    function validateTokens(address[] memory _tokens) internal pure {
        for (uint256 i = 0; i < _tokens.length - 1; i++) {
            require(_tokens[i] != _tokens[i + 1], "non unique tokens");
        }
    }

    function calculateFeeBPS(uint256 _route) public view returns (uint256 BPS_) {
        if (_route == 1) {
            BPS_ = aaveLending.FLASHLOAN_PREMIUM_TOTAL();
        } else if (_route == 2) {
            BPS_ = (makerLending.toll()) / (10 ** 14);
        } else if (_route == 3) {
            BPS_ = (balancerLending.getProtocolFeesCollector().getFlashLoanFeePercentage()) * 100;
        } else {
            revert("invalid route");
        }
    }

    function calculateFees(uint256[] memory _amounts, uint256 _BPS) internal pure returns (uint256[] memory) {
        uint256 length_ = _amounts.length;

        uint256[] memory fees = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            fees[i] = (_amounts[i] * _BPS) / (10 ** 4);
        }
        return fees;
    }

    event LogFlashloan(address indexed account, uint256 indexed route, address[] tokens, uint256[] amounts);
}
