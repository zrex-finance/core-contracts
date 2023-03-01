// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../lib/UniversalERC20.sol";

import { IFlashReceiver } from "./interfaces.sol";
import { FlashAggregatorHelper } from "./helpers.sol";

contract FlashAggregator is FlashAggregatorHelper {
    using UniversalERC20 for IERC20;

    event LogFlashloan(
        address indexed account,
        uint256 indexed route,
        address[] tokens,
        uint256[] amounts
    );
    
    receive() external payable {}

    constructor() {
        require(status == 0, "cannot call again");
        status = 1;
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

        (
            uint256 route_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data,(uint256, address, bytes));

        uint256[] memory _fees = calculateFees(_amounts,calculateFeeBPS(route_));
        uint256[] memory _initialBalances = calculateBalances(_assets, address(this));

        safeApprove(_assets, _amounts, _premiums, address(aaveLending));
        safeTransfer(_assets,_amounts, sender_);

        IFlashReceiver(sender_).executeOperation(
                _assets,
                _amounts,
                _fees,
                sender_,
                data_
            );

        uint256[] memory _finalBalances = calculateBalances(_assets,address(this));

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

        (
            uint256 route_,
            address[] memory assets_,
            uint256[] memory amounts_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data, (uint256, address[], uint256[], address, bytes));

        uint256[] memory _fees = calculateFees(amounts_,calculateFeeBPS(route_));
        uint256[] memory _initialBalances = calculateBalances(assets_, address(this));

        safeApprove(assets_, amounts_, _fees, address(makerLending));
        safeTransfer(assets_,amounts_, sender_);

        IFlashReceiver(sender_).executeOperation(
            assets_,
            amounts_,
            _fees,
            sender_,
            data_
        );
        uint256[] memory _finalBalances = calculateBalances(assets_, address(this));
        validateFlashloan(_initialBalances, _finalBalances, _fees);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
    
    /**
     * @notice Fallback function for balancer flashloan.
     */
    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory,
        uint256[] memory _fees,
        bytes memory _data
    ) external verifyDataHash(_data) {
        require(msg.sender == address(balancerLending), "not balancer sender");

        (
            uint256 route_,
            address[] memory assets_,
            uint256[] memory amounts_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data, (uint256, address[], uint256[], address, bytes));

        uint256[] memory fees_ = calculateFees(amounts_,calculateFeeBPS(route_));
        uint256[] memory initialBalances_ = calculateBalances(assets_, address(this));

        safeTransfer(assets_,amounts_, sender_);
        IFlashReceiver(sender_).executeOperation(
                assets_,
                amounts_,
                fees_,
                sender_,
                data_
            );

        uint256[] memory _finalBalances = calculateBalances(assets_, address(this));

        validateFlashloan(initialBalances_, _finalBalances, fees_);
        safeTransferWithFee(assets_,amounts_,_fees,address(balancerLending));
    }


    function routeAave(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(1, msg.sender, _data);
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
            0
        );
    }


    function routeMaker(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(2,_tokens,_amounts,msg.sender,_data);
        dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(
            IFlashReceiver(address(this)),
            _tokens[0],
            _amounts[0],
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
        bytes memory data_ = abi.encode(3,_tokens,_amounts,msg.sender,_data);
        dataHash = bytes32(keccak256(data_));

        balancerLending.flashLoan(
            IFlashReceiver(address(this)),
            tokens_,
            _amounts,
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
}