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

interface IAutoUniRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory);
    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);
}

abstract contract HelperContract {
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

    function getSwapUniData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount)
    public view returns(bytes memory data) {
        IAutoUniRouter.ExactInputSingleParams memory params = IAutoUniRouter.ExactInputSingleParams(
            _fromToken,
            _toToken == 0x0000000000000000000000000000000000000000 ? 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 : _toToken,
            500,
            _recipient,
            _amount,
            0,
            0
        );

        bytes[] memory swapData = new bytes[](1);
        swapData[0] = abi.encodeWithSelector(IAutoUniRouter.exactInputSingle.selector, params); 

        data = abi.encodeWithSelector(
            IAutoUniRouter.multicall.selector,
            block.timestamp * 2,
            swapData
        );
    }
}

contract EmitContractTest is Test, HelperContract {

    PositionRouter router;
    FlashResolver flashResolver;
    AaveResolver aaveResolver;

    address exchanges;

    ERC20 daiContract = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;
    address ethContract = 0x0000000000000000000000000000000000000000;

    constructor() HelperContract() {
        (router, flashResolver, exchanges) = setUp();
        aaveResolver = new AaveResolver();
    }

    function testOpenPosition() public {
        PositionRouter.Position memory position = PositionRouter.Position(
            msg.sender,
            address(daiContract),
            ethContract,
            1000 ether,
            2
        );

        // top up msg sender balance
        vm.prank(daiWhale);
        daiContract.transfer(msg.sender, position.amountIn);
        // approve tokens
        vm.prank(msg.sender);
        daiContract.approve(address(router), position.amountIn);

        uint256 loanAmount = position.amountIn * (position.sizeDelta - 1);

        address[] memory _tokens = new address[](1);
        _tokens[0] = position.debt;

        uint256[] memory _amts = new uint256[](1);
        _amts[0] = loanAmount;

        (,,uint16[] memory bestRoutes_, uint256 bestFee_) = flashResolver.getData(_tokens, _amts);

        uint256 swapAmount = position.amountIn * position.sizeDelta;
        uint256 swapAmountWithoutFee = swapAmount - (swapAmount * 3 / 10000);

        bytes memory _calldata = getCallbackData(
            position.debt,
            position.collateral,
            swapAmountWithoutFee,
            loanAmount + bestFee_
        );

        bytes memory _customdata;

        vm.prank(msg.sender);
        router.openPosition(position, false, _tokens, _amts, bestRoutes_[0], _calldata, _customdata);
    }

    function getCallbackData(
        address debt,
        address collateral,
        uint256 swapAmount,
        uint256 loanAmount
    ) public view returns(bytes memory _calldata) {
        address[] memory _targets = new address[](2);
        _targets[0] = address(aaveResolver);
        _targets[1] = address(aaveResolver);

        bytes[] memory _datas = new bytes[](2);
        _datas[0] = abi.encodeWithSelector(aaveResolver.deposit.selector, collateral, type(uint256).max);
        _datas[1] = abi.encodeWithSelector(aaveResolver.borrow.selector, debt, loanAmount, 1);

        bytes[] memory _customDatas = new bytes[](1);
        bytes memory _uniData = getSwapUniData(debt, collateral, address(exchanges), swapAmount);
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