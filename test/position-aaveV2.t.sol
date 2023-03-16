// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "../src/dependencies/openzeppelin/contracts/IERC20.sol";

import { DataTypes } from "../src/protocol/libraries/types/DataTypes.sol";
import { UniversalERC20 } from "../src/libraries/tokens/UniversalERC20.sol";

import { UniswapHelper } from "./uniswap.sol";
import { HelperContract, Deployer } from "./deployer.sol";

contract LendingHelper is HelperContract, UniswapHelper, Deployer {
    uint256 RATE_TYPE = 1;
    string NAME = "AaveV2";

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
    using UniversalERC20 for IERC20;

    function testLongPositionAccount() public {
        DataTypes.Position memory _position = DataTypes.Position(
            msg.sender,
            address(daiC),
            wethC,
            1000 ether,
            2,
            0,
            0,
            0
        );

        topUpTokenBalance(daiC, daiWhale, _position.amountIn);

        openPosition(_position);
        closePosition(_position);
    }

    function LongPositionETH() public {
        DataTypes.Position memory _position = DataTypes.Position(msg.sender, address(0), wethC, 2 ether, 2, 0, 0, 0);

        openPosition(_position);
        closePosition(_position);
    }

    function openPosition(DataTypes.Position memory _position) public {
        bool isEth = IERC20(_position.debt).isETH();

        if (!isEth) {
            vm.prank(msg.sender);
            IERC20(_position.debt).approve(address(router), _position.amountIn);
        }

        (address _token, uint256 _amount, uint16 _route, bytes memory _data) = _openPosition(_position);

        uint256 value = isEth ? _position.amountIn : 0;

        vm.prank(msg.sender);
        router.openPosition{ value: value }(_position, _token, _amount, _route, _data);
    }

    function closePosition(DataTypes.Position memory _position) public {
        uint256 index = router.positionsIndex(_position.account);
        bytes32 key = router.getKey(_position.account, index);

        (, , , , , uint256 _collateralAmount, uint256 _borrowAmount, ) = router.positions(key);

        (address _token, uint256 _amount, uint16 _route) = getFlashloanData(_position.debt, _borrowAmount);

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
        router.closePosition(key, _token, _amount, _route, _calldata);
    }

    function testShortPosition() public {
        uint256 shortAmt = 2000 ether;

        bytes memory swapdata = getMulticalSwapData(daiC, wethC, address(router), shortAmt);
        bytes memory _unidata = abi.encodeWithSelector(uniswapConnector.swap.selector, wethC, daiC, shortAmt, swapdata);

        DataTypes.SwapParams memory _params = DataTypes.SwapParams(daiC, wethC, shortAmt, "UniswapAuto", _unidata);

        topUpTokenBalance(daiC, daiWhale, shortAmt);

        // approve tokens
        vm.prank(msg.sender);
        IERC20(daiC).approve(address(router), shortAmt);

        uint256 exchangeAmt = quoteExactInputSingle(daiC, wethC, shortAmt);

        DataTypes.Position memory _position = DataTypes.Position(msg.sender, wethC, usdcC, exchangeAmt, 2, 0, 0, 0);

        openShort(_position, _params);

        closePosition(_position);
    }

    function openShort(DataTypes.Position memory _position, DataTypes.SwapParams memory _params) public {
        (address _token, uint256 _amount, uint16 _route, bytes memory _data) = _openPosition(_position);

        vm.prank(msg.sender);
        router.swapAndOpen(_position, _token, _amount, _route, _data, _params);
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

    function getFlashloanData(address lT, uint256 lA) public view returns (address, uint256, uint16) {
        lT = IERC20(lT).isETH() ? wethC : lT;

        address[] memory _tokens = new address[](1);
        uint256[] memory _amts = new uint256[](1);
        _tokens[0] = lT;
        _amts[0] = lA;

        (, , uint16[] memory _bestRoutes, ) = flashResolver.getData(_tokens, _amts);

        return (lT, lA, _bestRoutes[0]);
    }

    function _openPosition(
        DataTypes.Position memory _position
    ) public view returns (address, uint256, uint16, bytes memory) {
        uint256 loanAmt = _position.amountIn * (_position.sizeDelta - 1);

        (address _token, uint256 _amount, uint16 _route) = getFlashloanData(_position.debt, loanAmt);

        uint256 swapAmount = _position.amountIn * _position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - ((swapAmount * 3) / 10000);

        bytes memory _calldata = getOpenCallbackData(_position, swapAmountWithoutFee);

        return (_token, _amount, _route, _calldata);
    }
}
