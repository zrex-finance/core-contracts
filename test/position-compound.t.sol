// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/positions/PositionRouter.sol";

import "../src/connectors/CompoundV3.sol";

import "../src/swap/SwapRouter.sol";
import "../src/flashloans/FlashResolver.sol";
import "../src/flashloans/FlashAggregator.sol";

import { UniswapHelper } from "./uniswap-helper.t.sol";

contract HelperContract is UniswapHelper, Test {

    address usdcC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address usdcWhale = 0x5414d89a8bF7E99d732BC52f3e6A3Ef461c0C078;

    function topUpTokenBalance(address token, address whale, uint256 amt) public {
        // top up msg sender balance
        vm.prank(whale);
        ERC20(token).transfer(msg.sender, amt);
    }
}

contract LendingHelper is HelperContract {
    CompoundV3Connector compResolver;

    address USDC_MARKET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;

    constructor() {
        compResolver = new CompoundV3Connector();
    }

    function getCollateralAmt(
        address _token,
        address _recipient
    ) public view returns (uint256 collateralAmount) {
        collateralAmount = compResolver.collateralBalanceOf(
            USDC_MARKET, 
            _recipient,
            _token == ethC || _token == ethC2 ? wethC : _token
        );
    }

    function getBorrowAmt(
        address /* _token */,
        address _recipient
    ) public view returns (uint256 borrowAmount) {
        borrowAmount = compResolver.borrowBalanceOf(USDC_MARKET, _recipient);
    }
}

contract PositionCompound is LendingHelper {

    SwapRouter swapRouter;
    PositionRouter router;
    FlashResolver flashResolver;

    SharedStructs.Position position;

    constructor() {
        setUp();
    }

    function setUp() public {
        swapRouter = new SwapRouter();
        FlashAggregator flashloanAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashloanAggregator));

        uint256 fee = 3;
        address treasury = msg.sender;

        router = new PositionRouter(
            address(flashloanAggregator),
            address(swapRouter),
            fee,
            treasury,
            address(compResolver),
            address(0),
            address(0)
        );
        console.log("router", address(router));
    }

    function OpenAndClosePosition() public {
        position = SharedStructs.Position(
            msg.sender,
            address(usdcC),
            ethC2,
            1000000000,
            2,
            0,
            0
        );

        topUpTokenBalance(usdcC, usdcWhale, position.amountIn);
        
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
            uint16 route
        ) = getFlashloanData(position.debt, loanAmt);

        uint256 swapAmount = position.amountIn * position.sizeDelta;
        // protocol fee 3% denominator 10000
        uint256 swapAmountWithoutFee = swapAmount - (swapAmount * 3 / 10000);

        bytes memory _calldata = getOpenCallbackData(
            position.debt,
            position.collateral,
            swapAmountWithoutFee
        );

        vm.prank(msg.sender);
        router.openPosition(position, _tokens, _amts, route, _calldata, bytes(""));
    }

      function closePosition() public {
        uint256 index = router.positionsIndex(msg.sender);
        bytes32 key = router.getKey(msg.sender, index);

        (,,,,,uint256 collateralAmount, uint256 borrowAmount) = router.positions(key);

        (   
            address[] memory _tokens,
            uint256[] memory _amts,
            uint16 _route
        ) = getFlashloanData(position.debt, borrowAmount);

        bytes memory _calldata = getCloseCallbackData(
            position.debt,
            position.collateral,
            collateralAmount,
            borrowAmount,
            key
        );

        vm.prank(msg.sender);
        router.closePosition(key, _tokens, _amts, _route, _calldata, bytes(""));
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
        _datas[0] = abi.encode(borrowAmt, debt, 2, abi.encode(USDC_MARKET));
        _datas[1] = abi.encode(swapAmt, collateral, 2, abi.encode(USDC_MARKET));

        bytes memory _uniData = getMulticalSwapData(collateral, debt, address(swapRouter), swapAmt);
        _datas[2] = abi.encode(debt, collateral, swapAmt, 1, _uniData);

        _calldata = abi.encode(
            router.closePositionCallback.selector,
            _datas,
            _customDatas
        );
    }

    function getOpenCallbackData(
        address debt,
        address collateral,
        uint256 swapAmount
    ) public view returns(bytes memory _calldata) {
        bytes memory _uniData = getMulticalSwapData(debt, collateral, address(swapRouter), swapAmount);
        bytes[] memory _customDatas = new bytes[](1);

        uint256 index = router.positionsIndex(msg.sender);
        bytes32 key = router.getKey(msg.sender, index + 1);

        _customDatas[0] = abi.encode(key);

        bytes[] memory _datas = new bytes[](3);
        _datas[0] = abi.encode(collateral, debt, swapAmount, 1, _uniData);
        // deposit(dynamic amt,token,route)
        _datas[1] = abi.encode(collateral, 2, abi.encode(USDC_MARKET));
        // borrow(dynamic amt,token,route,mode)
        _datas[2] = abi.encode(debt, 2, abi.encode(USDC_MARKET));

        _calldata = abi.encode(
            router.openPositionCallback.selector,
            _datas,
            _customDatas
        );
    }
}