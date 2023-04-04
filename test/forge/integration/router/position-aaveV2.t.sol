// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { IRouter } from 'contracts/interfaces/IRouter.sol';
import { UniversalERC20 } from 'contracts/lib/UniversalERC20.sol';

import { Deployer } from '../../utils/deployer.sol';
import { UniswapHelper } from '../../utils/uniswap.sol';
import { HelperContract } from '../../utils/helper.sol';

contract LendingHelper is HelperContract, UniswapHelper, Deployer {
    uint256 RATE_TYPE = 1;
    string NAME = 'AaveV2';

    function getCollateralAmt(address _token, address _recipient) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveV2Connector.getCollateralBalance(_token == ethC ? wethC : _token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveV2Connector.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.payback.selector, _token, _amount, RATE_TYPE);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.deposit.selector, _token);
    }

    function getBorrowData(address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.borrow.selector, _token, RATE_TYPE);
    }
}

contract PositionAaveV2 is LendingHelper {
    function test_OpenPosition_ClosePosition() public {
        DataTypes.Position memory _position = DataTypes.Position(msg.sender, daiC, wethC, 1000 ether, 21000, 0, 0);

        topUpTokenBalance(daiC, daiWhale, _position.amountIn);

        openPosition(_position);
        uint256 index = router.positionsIndex(_position.account);

        closePosition(_position, index);
    }

    function test_OpenAndClose_TwoPosition() public {
        DataTypes.Position memory _position = DataTypes.Position(msg.sender, daiC, wethC, 1000 ether, 21000, 0, 0);

        topUpTokenBalance(daiC, daiWhale, _position.amountIn * 2);

        openPosition(_position);
        uint256 index1 = router.positionsIndex(_position.account);

        openPosition(_position);
        uint256 index2 = router.positionsIndex(_position.account);

        closePosition(_position, index1);
        closePosition(_position, index2);
    }

    function test_SwapAndOpen_ClosePosition() public {
        uint256 shortAmt = 2000 ether;

        bytes memory swapdata = getMulticalSwapData(daiC, wethC, address(router), shortAmt);
        bytes memory _unidata = abi.encodeWithSelector(uniswapConnector.swap.selector, wethC, daiC, shortAmt, swapdata);

        IRouter.SwapParams memory _params = IRouter.SwapParams(daiC, wethC, shortAmt, 'UniswapAuto', _unidata);

        topUpTokenBalance(daiC, daiWhale, shortAmt);

        // approve tokens
        vm.prank(msg.sender);
        ERC20(daiC).approve(address(router), shortAmt);

        uint256 exchangeAmt = quoteExactInputSingle(daiC, wethC, shortAmt);

        DataTypes.Position memory _position = DataTypes.Position(msg.sender, wethC, usdcC, exchangeAmt, 21000, 0, 0);

        openShort(_position, _params);
        uint256 index = router.positionsIndex(_position.account);

        closePosition(_position, index);
    }

    function openPosition(DataTypes.Position memory _position) public {
        // approve tokens
        vm.prank(msg.sender);
        ERC20(_position.debt).approve(address(router), _position.amountIn);

        (uint16 _route, bytes memory _data) = _openPosition(_position);

        vm.prank(msg.sender);
        router.openPosition(_position, _route, _data);
    }

    function closePosition(DataTypes.Position memory _position, uint256 _index) public {
        bytes32 key = router.getKey(_position.account, _index);

        (, , , , , uint256 _collateralAmount, uint256 _borrowAmount) = router.positions(key);

        uint16 _route = getFlashloanData(_position.debt, _borrowAmount);

        address account = router.accounts(_position.account);

        bytes memory _calldata = getCloseCallbackData(
            _position.debt,
            _position.collateral,
            _collateralAmount,
            _borrowAmount,
            account,
            key
        );

        vm.prank(msg.sender);
        router.closePosition(key, _position.debt, _borrowAmount, _route, _calldata);
    }

    function openShort(DataTypes.Position memory _position, IRouter.SwapParams memory _params) public {
        (uint16 _route, bytes memory _data) = _openPosition(_position);

        vm.prank(msg.sender);
        router.swapAndOpen(_position, _route, _data, _params);
    }

    function getOpenCallbackData(
        DataTypes.Position memory _position,
        uint256 swapAmount
    ) public view returns (bytes memory _calldata) {
        uint256 index = router.positionsIndex(_position.account);
        bytes32 key = router.getKey(_position.account, index + 1);

        string[] memory _targetNames = new string[](3);
        _targetNames[0] = uniswapConnector.name();
        _targetNames[1] = aaveV2Connector.name();
        _targetNames[2] = aaveV2Connector.name();

        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encode(key);

        address account = router.accounts(_position.account);

        if (account == address(0)) {
            account = router.predictDeterministicAddress(_position.account);
        }

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = getSwapData(_position.debt, _position.collateral, account, swapAmount);
        _datas[1] = getDepositData(_position.collateral);
        _datas[2] = getBorrowData(_position.debt);

        _calldata = abi.encode(accountImpl.openPositionCallback.selector, _targetNames, _datas, _customDatas);
    }

    function getCloseCallbackData(
        address debt,
        address collateral,
        uint256 swapAmt,
        uint256 borrowAmt,
        address account,
        bytes32 key
    ) public view returns (bytes memory _calldata) {
        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encodePacked(key);

        string[] memory _targetNames = new string[](3);
        _targetNames[0] = aaveV2Connector.name();
        _targetNames[1] = aaveV2Connector.name();
        _targetNames[2] = uniswapConnector.name();

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = getPaybackData(borrowAmt, debt);
        _datas[1] = getWithdrawData(swapAmt, collateral);
        _datas[2] = getSwapData(collateral, debt, account, swapAmt);

        _calldata = abi.encode(accountImpl.closePositionCallback.selector, _targetNames, _datas, _customDatas);
    }

    function getFlashloanData(address lT, uint256 lA) public view returns (uint16) {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amts = new uint256[](1);
        _tokens[0] = lT;
        _amts[0] = lA;

        (, , uint16[] memory _bestRoutes, ) = flashResolver.getData(_tokens, _amts);

        return _bestRoutes[0];
    }

    function _openPosition(DataTypes.Position memory _position) public view returns (uint16, bytes memory) {
        uint256 loanAmt = _position.amountIn * (_position.leverage - 10000);

        uint16 _route = getFlashloanData(_position.debt, loanAmt);

        uint256 swapAmount = (_position.amountIn * _position.leverage) / 10000;
        // protocol fee 0.5% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - ((swapAmount * 50) / 10000);

        bytes memory _calldata = getOpenCallbackData(_position, swapAmountWithoutFee);

        return (_route, _calldata);
    }
}
