// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SharedStructs } from "../src/lib/SharedStructs.sol";

import { AaveV2Connector } from "../src/connectors/AaveV2.sol";

import { PositionRouter } from "../src/positions/PositionRouter.sol";
import { FlashReceiver } from "../src/positions/FlashReceiver.sol";

import { SwapRouter } from "../src/swap/SwapRouter.sol";
import { FlashResolver } from "../src/flashloans/FlashResolver.sol";
import { FlashAggregator } from "../src/flashloans/FlashAggregator.sol";

import { Regestry } from "../src/accounts/regestry.sol";
import { Proxy } from "../src/accounts/Proxy.sol";
import { Implementation } from "../src/accounts/implementation.sol";
import { Implementations } from "../src/accounts/implementations.sol";

import { UniswapHelper } from "./uniswap-helper.t.sol";

contract HelperContract is UniswapHelper, Test {

    address usdcC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).transfer(msg.sender, amt);
    }
}

contract LendingHelper is HelperContract {
    AaveV2Connector aaveConnector;

    uint256 RATE_TYPE = 1;

    constructor() {
        aaveConnector = new AaveV2Connector();
    }

    function getCollateralAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveConnector.getCollateralBalance(
            _token == ethC ? wethC : _token, _recipient
        );        
    }

    function getBorrowAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveConnector.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }
}

contract PositionAccount is LendingHelper {

    SwapRouter swapRouter;
    FlashResolver flashResolver;

    Regestry regestry;
    PositionRouter router;

    Proxy accountProxy;
    Implementation implementation;
    Implementations implementations;

    constructor() {
        swapRouter = new SwapRouter();
        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));

        router = new PositionRouter(
            address(flashloanAggregator),
            address(swapRouter),
            3,
            msg.sender,
            address(0),
            address(aaveConnector),
            address(0)
        );

        implementation = new Implementation();
        implementations = new Implementations();

        implementations.setDefaultImplementation(address(implementation));

        accountProxy = new Proxy(address(implementations));
        regestry = new Regestry(address(accountProxy), address(router));
    }

    function testCreateAccountWithOpenLongPosition() public {
        vm.prank(msg.sender);
        address account = regestry.predictDeterministicAddress();

        SharedStructs.Position memory _position = SharedStructs.Position(
            account,
            address(daiC),
            wethC,
            1000 ether,
            2,
            0,
            0
        );

        topUpTokenBalance(daiC, daiWhale, _position.amountIn);
        
        openPositionWithCreateAccount(_position);
        closePosition(_position);
    }

    function testLongPositionAccount() public {
        vm.prank(msg.sender);
        address account = regestry.createAccount(msg.sender);

        SharedStructs.Position memory _position = SharedStructs.Position(
            account,
            address(daiC),
            wethC,
            1000 ether,
            2,
            0,
            0
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
            account,
            wethC,
            usdcC,
            exchangeAmt,
            2,
            0,
            0
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
        _position.account.call(_open);
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
        _position.account.call(_open);
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
        _position.account.call(_close);
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
        _datas[0] = abi.encode(borrowAmt, debt, 1, abi.encode(1));
        _datas[1] = abi.encode(swapAmt, collateral, 1, bytes(""));

        bytes memory _uniData = getMulticalSwapData(collateral, debt, address(router), swapAmt);
        _datas[2] = abi.encode(debt, collateral, swapAmt, 1, _uniData);

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
        bytes memory _uniData = getMulticalSwapData(
            _position.debt, _position.collateral, address(router), swapAmount
        );
        bytes[] memory _customDatas = new bytes[](1);

        uint256 index = router.positionsIndex(address(_position.account));
        bytes32 key = router.getKey(address(_position.account), index + 1);

        _customDatas[0] = abi.encode(key);

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = abi.encode(_position.collateral, _position.debt, swapAmount, 1, _uniData);
        // deposit(dynamic amt,token,route)
        _datas[1] = abi.encode(_position.collateral, 1, bytes(""));
        // borrow(dynamic amt,token,route,mode)
        _datas[2] = abi.encode(_position.debt, 1, abi.encode(1));

        _calldata = abi.encode(
            router.openPositionCallback.selector,
            _datas,
            _customDatas
        );
    }
}