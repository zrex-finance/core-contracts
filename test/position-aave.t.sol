// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/positions/Router.sol";
import "../src/positions/interfaces.sol";

import "../src/connectors/protocols/aave/v2/main.sol";

import "../src/exchanges/main.sol";
import "../src/flashloans/receiver/main.sol";
import "../src/flashloans/resolver/main.sol";
import "../src/flashloans/aggregator/main.sol";

import { UniswapHelper } from "./uniswap-helper.t.sol";

contract HelperContract is UniswapHelper, Test {

    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).transfer(msg.sender, amt);
    }
}

contract LendingHelper is HelperContract {
    AaveResolver aaveResolver;

    uint256 RATE_TYPE = 1;

    constructor() {
        aaveResolver = new AaveResolver();
    }

    function getLendingCloseCalldata(
        address pT,
        uint256 pA,
        address wT,
        uint256 wA
    ) public view returns(address[] memory, bytes[] memory) {
        address[] memory _targets = new address[](2);
        _targets[0] = address(aaveResolver);
        _targets[1] = address(aaveResolver);

        bytes[] memory _datas = new bytes[](2);
        _datas[0] = abi.encodeWithSelector(aaveResolver.payback.selector, pT, pA, RATE_TYPE);
        _datas[1] = abi.encodeWithSelector(aaveResolver.withdraw.selector, wT, wA);

        return(_targets, _datas);
    }

    function getLendingOpenCalldata(
        address dT,
        uint256 dA,
        address bT,
        uint256 bA
    ) public view returns(address[] memory, bytes[] memory) {
        address[] memory _targets = new address[](2);
        _targets[0] = address(aaveResolver);
        _targets[1] = address(aaveResolver);

        bytes[] memory _datas = new bytes[](2);
        _datas[0] = abi.encodeWithSelector(aaveResolver.deposit.selector, dT, dA);
        _datas[1] = abi.encodeWithSelector(aaveResolver.borrow.selector, bT, bA, RATE_TYPE);

        return(_targets, _datas);
    }

    function getCollateralAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveResolver.getCollateralBalance(
            _token == ethC ? wethC : _token, _recipient
        );        
    }

    function getBorrowAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveResolver.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }
}

contract PositionAave is LendingHelper {

    PositionRouter router;
    FlashResolver flashResolver;
    Exchanges exchanges;

    PositionRouter.Position position;

    constructor() {
        setUp();
    }

    function setUp() public {
        exchanges = new Exchanges();
        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));
        FlashReceiver flashloanReciever = new FlashReceiver(address(flashloanAggregator));

        uint256 fee = 3;
        address treasury = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        router = new PositionRouter(address(flashloanReciever), address(exchanges), fee, treasury);
        flashloanReciever.setRouter(address(router));
    }

    function testOpenAndClosePosition() public {
        position = PositionRouter.Position(
            msg.sender,
            address(daiC),
            ethC,
            1000 ether,
            2
        );

        topUpTokenBalance(daiC, daiWhale, position.amountIn);
        
        // approve tokens
        vm.prank(msg.sender);
        ERC20(position.debt).approve(address(router), position.amountIn);
        
        openPosition();
        closePosition();
    }

    function openPosition() public {
        uint256 loanAmt = position.amountIn * (position.sizeDelta - 1);

        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 route, 
            uint256 fee
        ) = getFlashloanData(position.debt, loanAmt);

        uint256 swapAmount = position.amountIn * position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - (swapAmount * 3 / 10000);

        bytes memory _calldata = getOpenCallbackData(
            position.debt,
            position.collateral,
            swapAmountWithoutFee,
            loanAmt + fee
        );

        vm.prank(msg.sender);
        router.openPosition(position, false, _tokens, _amts, route, _calldata, bytes(""));
    }

      function closePosition() public {
        uint256 index = router.positionsIndex(msg.sender);
        bytes32 key = router.getKey(msg.sender, index);

        uint256 collateralAmount = getCollateralAmt(position.collateral, address(router));
        uint256 borrowAmount = getBorrowAmt(position.debt, address(router));

        (   
            address[] memory __tokens,
            uint256[] memory __amts,
            uint16 _route,
        ) = getFlashloanData(position.debt, borrowAmount * 1005 / 1000);

        bytes memory __calldata = getCloseCallbackData(
            position.debt,
            position.collateral,
            collateralAmount,
            key
        );

        vm.prank(msg.sender);
        router.closePosition(key, __tokens, __amts, _route, __calldata, bytes(""));
    }

    function getFlashloanData(
        address lT,
        uint256 lA
    ) public view returns(address[] memory, uint256[] memory, uint16, uint256) {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amts = new uint256[](1);
        _tokens[0] = lT;
        _amts[0] = lA;

        (,,uint16[] memory _bestRoutes, uint256 _bestFee) = flashResolver.getData(_tokens, _amts);

        return (_tokens, _amts, _bestRoutes[0], _bestFee);
    }

    function getCloseCallbackData(
        address debt,
        address collateral,
        uint256 swapAmount,
        bytes32 key
    ) public view returns(bytes memory _calldata) {
        (
            address[] memory _targets,
            bytes[] memory _datas
        ) = getLendingCloseCalldata(debt, type(uint256).max, collateral, type(uint256).max);

        bytes memory _uniData = getMulticalSwapData(collateral, debt, address(exchanges), swapAmount);
        bytes[] memory _customDatas = new bytes[](2);

        // toToken, fromToken, amount, route, calldata
        _customDatas[0] = abi.encode(debt, collateral, swapAmount, 1, _uniData);
        _customDatas[1] = abi.encodePacked(key);
        _calldata = abi.encode(
            router.closePositionCallback.selector,
            _targets,
            _datas,
            _customDatas,
            msg.sender
        );
    }

    function getOpenCallbackData(
        address debt,
        address collateral,
        uint256 swapAmount,
        uint256 loanAmount
    ) public view returns(bytes memory _calldata) {
        (
            address[] memory _targets,
            bytes[] memory _datas
        ) = getLendingOpenCalldata(collateral, type(uint256).max, debt, loanAmount);

        bytes memory _uniData = getMulticalSwapData(debt, collateral, address(exchanges), swapAmount);
        bytes[] memory _customDatas = new bytes[](1);

        // toToken, fromToken, amount, route, calldata
        _customDatas[0] = abi.encode(collateral, debt, swapAmount, 1, _uniData);
        _calldata = abi.encode(
            router.openPositionCallback.selector,
            _targets,
            _datas,
            _customDatas,
            msg.sender
        );
    }
}