// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SharedStructs } from "../src/lib/SharedStructs.sol";

import { UniswapHelper } from "./uniswap.sol";
import { HelperContract, Deployer } from "./deployer.sol";

contract LendingHelper is HelperContract, UniswapHelper, Deployer {

    uint256 RATE_TYPE = 1;
    uint256 ROUTE = 1;

    function getCollateralAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveV2Connector.getCollateralBalance(
            _token == ethC ? wethC : _token, _recipient
        );        
    }

    function getBorrowAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveV2Connector.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns(bytes memory _data) {
      _data = abi.encode(_amount, _token, ROUTE, abi.encode(RATE_TYPE));
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns(bytes memory _data) {
      _data = abi.encode(_amount, _token, ROUTE, bytes(""));
    }

    function getDepositData(address _token) public view returns(bytes memory _data) {
      _data = abi.encode(_token, ROUTE, bytes(""));
    }

    function getBorrowData(address _token) public view returns(bytes memory _data) {
      _data = abi.encode(_token, ROUTE, abi.encode(RATE_TYPE));
    }
}

contract PositionAaaveV2 is LendingHelper {

    function testCreateAccountWithOpenLongPosition() public {
        vm.prank(msg.sender);
        address account = regestry.predictDeterministicAddress();

        SharedStructs.Position memory _position = SharedStructs.Position(
            account, address(daiC), wethC, 1000 ether, 2, 0, 0
        );

        topUpTokenBalance(daiC, daiWhale, _position.amountIn);
        
        openPositionWithCreateAccount(_position);
        closePosition(_position);
    }

    function testLongPositionAccount() public {
        vm.prank(msg.sender);
        address account = regestry.createAccount(msg.sender);

        SharedStructs.Position memory _position = SharedStructs.Position(
            account,address(daiC),wethC,1000 ether,2,0,0
        );

        topUpTokenBalance(daiC, daiWhale, _position.amountIn);
        
        openPosition(_position);
        closePosition(_position);
    }

    function testShortPosition() public {
        vm.prank(msg.sender);
        address account = regestry.createAccount(msg.sender);

        uint256 shortAmt = 2000 ether;

        bytes memory _uniData = getMulticalSwapData(daiC, wethC, address(account), shortAmt);
        bytes memory datas =  abi.encode(wethC, daiC, shortAmt, 1, _uniData);

        topUpTokenBalance(daiC, daiWhale, shortAmt);

        // approve tokens
        vm.prank(msg.sender);
        ERC20(daiC).approve(address(account), shortAmt);

        uint256 exchangeAmt = quoteExactInputSingle(daiC, wethC, shortAmt);

        SharedStructs.Position memory _position = SharedStructs.Position(
            account,wethC,usdcC,exchangeAmt,2,0,0
        );

        openShort(_position, datas);

        closePosition(_position);
    }

    function openShort(SharedStructs.Position memory _position, bytes memory _swap) 
        public 
    {
        (
            /* bool isShort */,
            address[] memory _tokens,
            uint256[] memory _amts,
            uint256 route,
            bytes memory _data,
            /* bytes memory _customdata */
        ) = _openPosition(_position);

        bytes memory _open = abi.encodeWithSelector(
            implementation.openPosition.selector, _position, true, _tokens, _amts, route, _data, _swap
        );
        
        vm.prank(msg.sender);
        (bool success, ) = _position.account.call(_open);
        require(success);
    }

    function openPositionWithCreateAccount(SharedStructs.Position memory _position) 
        public 
    {
        // approve tokens
        vm.prank(msg.sender);
        ERC20(_position.debt).approve(address(regestry), _position.amountIn);

        (
            bool isShort,
            address[] memory _tokens,
            uint256[] memory _amts,
            uint256 route,
            bytes memory _data,
            bytes memory _customdata
        ) = _openPosition(_position);

        vm.prank(msg.sender);
        regestry.createWithOpen(_position, isShort, _tokens, _amts, route, _data, _customdata);
    }

    function openPosition(SharedStructs.Position memory _position) 
        public 
    {
        // approve tokens
        vm.prank(msg.sender);
        ERC20(_position.debt).approve(_position.account, _position.amountIn);

        (
            bool isShort,
            address[] memory _tokens,
            uint256[] memory _amts,
            uint256 route,
            bytes memory _data,
            bytes memory _customdata
        ) = _openPosition(_position);

        bytes memory _open = abi.encodeWithSelector(
            implementation.openPosition.selector, _position, isShort, _tokens, _amts, route, _data, _customdata
        );
        
        vm.prank(msg.sender);
        (bool success, ) = _position.account.call(_open);
        require(success);
    }

    function closePosition(SharedStructs.Position memory _position)
        public 
    {

        uint256 index = router.positionsIndex(_position.account);
        bytes32 key = router.getKey(_position.account, index);

        (,,,,,uint256 _collateralAmount, uint256 _borrowAmount) = router.positions(key);

        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 _route
        ) = getFlashloanData(_position.debt, _borrowAmount);

        bytes memory _calldata = getCloseCallbackData(
            _position.debt,
            _position.collateral,
            _collateralAmount,
            _borrowAmount,
            key
        );

        bytes memory _close = abi.encodeWithSelector(
            implementation.closePosition.selector, key, _tokens, _amts, _route, _calldata, bytes("")
        );

        vm.prank(msg.sender);
        (bool success, ) = _position.account.call(_close);
        require(success);
    }

    function getCloseCallbackData(
        address debt,
        address collateral,
        uint256 swapAmt,
        uint256 borrowAmt,
        bytes32 key
    ) public view returns(bytes memory _calldata) {

        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encodePacked(key);

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = getPaybackData(borrowAmt, debt);
        _datas[1] = getWithdrawData(swapAmt, collateral);
        _datas[2] = getSwapData(collateral, debt, address(router), swapAmt);

        _calldata = abi.encode(
            router.closePositionCallback.selector,
            _datas,
            _customDatas
        );
    }

    function getOpenCallbackData(
        SharedStructs.Position memory _position,
        uint256 swapAmount
    ) public view returns(bytes memory _calldata) {
        uint256 index = router.positionsIndex(address(_position.account));
        bytes32 key = router.getKey(address(_position.account), index + 1);

        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encode(key);

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = getSwapData( _position.debt, _position.collateral, address(router), swapAmount);
        _datas[1] = getDepositData(_position.collateral);
        _datas[2] = getBorrowData(_position.debt);

        _calldata = abi.encode(
            router.openPositionCallback.selector,
            _datas,
            _customDatas
        );
    }

    function getFlashloanData(
        address lT,
        uint256 lA
    ) public view returns(address[] memory, uint256[] memory, uint16) {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amts = new uint256[](1);
        _tokens[0] = lT;
        _amts[0] = lA;

        (,,uint16[] memory _bestRoutes,) = flashResolver.getData(_tokens, _amts);

        return (_tokens, _amts, _bestRoutes[0]);
    }

    function _openPosition(SharedStructs.Position memory _position) 
        public 
        view 
        returns (bool, address[] memory, uint256[] memory, uint256, bytes memory, bytes memory)
    {
        uint256 loanAmt = _position.amountIn * (_position.sizeDelta - 1);

        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 route
        ) = getFlashloanData(_position.debt, loanAmt);

        uint256 swapAmount = _position.amountIn * _position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - (swapAmount * 3 / 10000);

        bytes memory _calldata = getOpenCallbackData(_position, swapAmountWithoutFee);

        return (false, _tokens, _amts, route, _calldata, bytes(""));
    }
}