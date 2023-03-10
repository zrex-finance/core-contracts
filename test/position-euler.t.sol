// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SharedStructs } from "../src/lib/SharedStructs.sol";

import { UniswapHelper } from "./uniswap.sol";
import { HelperContract, Deployer } from "./deployer.sol";

contract LendingHelper is HelperContract, UniswapHelper, Deployer {
    uint256 SUB_ACCOUNT_ID = 0;
    string NAME = "Euler";
    uint256 route = 3;

    function getCollateralAmt(address _token, address _recipient) public view returns (uint256 collateralAmount) {
        collateralAmount = eulerConnector.collateralBalanceOf(
            _token == ethC || _token == ethC2 ? wethC : _token,
            _recipient,
            SUB_ACCOUNT_ID
        );
    }

    function getBorrowAmt(address _token, address _recipient) public view returns (uint256 borrowAmount) {
        borrowAmount = eulerConnector.borrowBalanceOf(_token, _recipient, SUB_ACCOUNT_ID);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(eulerConnector.repay.selector, SUB_ACCOUNT_ID, _token, _amount);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(eulerConnector.withdraw.selector, SUB_ACCOUNT_ID, _token, _amount);
    }

    function getDepositData(address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(eulerConnector.deposit.selector, SUB_ACCOUNT_ID, _token, true);
    }

    function getBorrowData(address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(eulerConnector.borrow.selector, SUB_ACCOUNT_ID, _token);
    }
}

contract PositionEuler is LendingHelper {
    function testLongPositionAccount() public {
        SharedStructs.Position memory _position = SharedStructs.Position(msg.sender, usdcC, wethC, 1000000000, 2, 0, 0);

        topUpTokenBalance(usdcC, usdcWhale, _position.amountIn);

        openPosition(_position);
        closePosition(_position);
    }

    function openPosition(SharedStructs.Position memory _position) public {
        // approve tokens
        vm.prank(msg.sender);
        ERC20(_position.debt).approve(address(router), _position.amountIn);

        (address _token, uint256 _amount, uint256 _route, bytes memory _data) = _openPosition(_position);

        vm.prank(msg.sender);
        router.openPosition(_position, _token, _amount, _route, _data);
    }

    function closePosition(SharedStructs.Position memory _position) public {
        uint256 index = router.positionsIndex(_position.account);
        bytes32 key = router.getKey(_position.account, index);

        (, , , , , uint256 _collateralAmount, uint256 _borrowAmount) = router.positions(key);

        (address _token, uint256 _amount, uint16 _route) = getFlashloanData(_position.debt, _borrowAmount);

        address account = router.accounts(_position.account);

        bytes memory _calldata = getCloseCallbackData(
            _position.debt,
            _position.collateral,
            _collateralAmount - 2, // TODO exlpain this
            _borrowAmount,
            account,
            key
        );

        vm.prank(msg.sender);
        router.closePosition(key, _token, _amount, _route, _calldata);
    }

    function testShortPosition() public {
        uint256 shortAmt = 2000 ether;

        bytes memory swapdata = getMulticalSwapData(daiC, usdcC, address(router), shortAmt);
        bytes memory _unidata = abi.encodeWithSelector(uniswapConnector.swap.selector, usdcC, daiC, shortAmt, swapdata);

        SharedStructs.SwapParams memory _params = SharedStructs.SwapParams(
            daiC,
            usdcC,
            shortAmt,
            "UniswapAuto",
            _unidata
        );

        topUpTokenBalance(daiC, daiWhale, shortAmt);

        // approve tokens
        vm.prank(msg.sender);
        ERC20(daiC).approve(address(router), shortAmt);

        uint256 exchangeAmt = quoteExactInputSingle(daiC, usdcC, shortAmt);

        SharedStructs.Position memory _position = SharedStructs.Position(
            msg.sender,
            usdcC,
            wethC,
            exchangeAmt,
            2,
            0,
            0
        );

        openShort(_position, _params);

        closePosition(_position);
    }

    function openShort(SharedStructs.Position memory _position, SharedStructs.SwapParams memory _params) public {
        (address _token, uint256 _amount, uint256 _route, bytes memory _data) = _openPosition(_position);

        vm.prank(msg.sender);
        router.swapAndOpen(_position, _token, _amount, _route, _data, _params);
    }

    function getOpenCallbackData(
        SharedStructs.Position memory _position,
        uint256 swapAmount
    ) public view returns (bytes memory _calldata) {
        uint256 index = router.positionsIndex(_position.account);
        bytes32 key = router.getKey(_position.account, index + 1);

        string[] memory _targetNames = new string[](3);
        _targetNames[0] = uniswapConnector.name();
        _targetNames[1] = eulerConnector.name();
        _targetNames[2] = eulerConnector.name();

        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encode(key);

        address account = router.accounts(_position.account);

        if (account == address(0)) {
            account = router.predictDeterministicAddress();
        }

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = getSwapData(_position.debt, _position.collateral, account, swapAmount);
        _datas[1] = getDepositData(_position.collateral);
        _datas[2] = getBorrowData(_position.debt);

        _calldata = abi.encode(implementation.openPositionCallback.selector, _targetNames, _datas, _customDatas);
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
        _targetNames[0] = eulerConnector.name();
        _targetNames[1] = eulerConnector.name();
        _targetNames[2] = uniswapConnector.name();

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = getPaybackData(borrowAmt, debt);
        _datas[1] = getWithdrawData(swapAmt, collateral);
        _datas[2] = getSwapData(collateral, debt, account, swapAmt);

        _calldata = abi.encode(implementation.closePositionCallback.selector, _targetNames, _datas, _customDatas);
    }

    function getFlashloanData(address lT, uint256 lA) public view returns (address, uint256, uint16) {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amts = new uint256[](1);
        _tokens[0] = lT;
        _amts[0] = lA;

        (, , uint16[] memory _bestRoutes, ) = flashResolver.getData(_tokens, _amts);

        return (lT, lA, _bestRoutes[0]);
    }

    function _openPosition(
        SharedStructs.Position memory _position
    ) public view returns (address, uint256, uint256, bytes memory) {
        uint256 loanAmt = _position.amountIn * (_position.sizeDelta - 1);

        (address _token, uint256 _amount, uint16 _route) = getFlashloanData(_position.debt, loanAmt);

        uint256 swapAmount = _position.amountIn * _position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - ((swapAmount * 3) / 10000);

        bytes memory _calldata = getOpenCallbackData(_position, swapAmountWithoutFee);

        return (_token, _amount, _route, _calldata);
    }
}
