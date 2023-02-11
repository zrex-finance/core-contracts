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

abstract contract HelperContract is UniswapHelper, Test {
    function setUp() public returns(PositionRouter, FlashResolver, address) {
        Exchanges exchanges = new Exchanges();
        FlashAggregator flashloanAggregator = new FlashAggregator();
        FlashResolver flashResolver = new FlashResolver(address(flashloanAggregator));
        FlashReceiver flashloanReciever = new FlashReceiver(address(flashloanAggregator));

        uint256 fee = 3;
        address treasury = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        PositionRouter _router = new PositionRouter(address(flashloanReciever), address(exchanges), fee, treasury);
        flashloanReciever.setRouter(address(_router));

        return (_router, flashResolver, address(exchanges));
    }

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).transfer(msg.sender, amt);
    }
}

contract EmitContractTest is HelperContract {

    PositionRouter router;
    FlashResolver flashResolver;
    AaveResolver aaveResolver;
    address exchanges;

    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    constructor() HelperContract() {
        (router, flashResolver, exchanges) = setUp();
        aaveResolver = new AaveResolver();
    }

    function testOpenPosition() public {
        PositionRouter.Position memory position = PositionRouter.Position(
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

    function getOpenCallbackData(
        address debt,
        address collateral,
        uint256 swapAmount,
        uint256 loanAmount
    ) public view returns(bytes memory _calldata) {
        (
            address[] memory _targets,
            bytes[] memory _datas
        ) = getAaveCalldata(collateral, type(uint256).max, debt, loanAmount);

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

    function getAaveCalldata(
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
        _datas[1] = abi.encodeWithSelector(aaveResolver.borrow.selector, bT, bA, 1);

        return(_targets, _datas);
    }
}