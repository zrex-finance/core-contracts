// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { IRouter } from 'contracts/interfaces/IRouter.sol';
import { UniversalERC20 } from 'contracts/lib/UniversalERC20.sol';

import { UniversalPosition } from './universal-position.sol';

contract PositionVenus is UniversalPosition {
    address public user = makeAddr('user');

    uint256 public leverage = 21000; // 2.1x

    function test_OpenPosition_ClosePosition() public {
        (DataTypes.Position memory position, uint256 index) = openPosition(
            user,
            getToken('usdc'),
            getToken('dai'),
            1000000000,
            leverage,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan)
        );

        closePosition(
            user,
            index,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan),
            position
        );
    }

    function test_OpenAndClose_TwoPosition() public {
        (DataTypes.Position memory position1, uint256 index1) = openPosition(
            user,
            getToken('usdc'),
            getToken('dai'),
            1000000000,
            leverage,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan)
        );

        (DataTypes.Position memory position2, uint256 index2) = openPosition(
            user,
            getToken('usdc'),
            getToken('dai'),
            1000000000,
            leverage,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan)
        );

        closePosition(
            user,
            index1,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan),
            position1
        );
        closePosition(
            user,
            index2,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan),
            position2
        );
    }

    function test_SwapAndOpen_ClosePosition() public {
        vm.prank(user);
        (DataTypes.Position memory position, uint256 index) = swapAndOpen(
            user,
            getToken('usdc'),
            getToken('dai'),
            getToken('wbnb'),
            3000000,
            leverage,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan)
        );

        vm.prank(user);
        closePosition(
            user,
            index,
            address(uniswapConnector),
            address(venusConnector),
            address(uniswapFlashloan),
            position
        );
    }

    // compound v2 connector integration

    function _getDepositCallData(address _collateral) public view override returns (bytes memory) {
        return abi.encodeWithSelector(venusConnector.deposit.selector, _collateral);
    }

    function _getBorrowCallData(address _debt) public view override returns (bytes memory) {
        return abi.encodeWithSelector(venusConnector.borrow.selector, _debt);
    }

    function _getPaybackCallData(address _debt, uint256 _borrowAmount) public view override returns (bytes memory) {
        return abi.encodeWithSelector(venusConnector.payback.selector, _debt, _borrowAmount);
    }

    function _getWithdrawCallData(
        address _collateral,
        uint256 _collateralAmount
    ) public view override returns (bytes memory) {
        return abi.encodeWithSelector(venusConnector.withdraw.selector, _collateral, _collateralAmount);
    }
}
