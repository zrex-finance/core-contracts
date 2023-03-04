// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

contract Tokens {
    address usdcC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address ethC = 0x0000000000000000000000000000000000000000;
    address ethC2 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
}

interface IUni {
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

    function swap(
        address toToken,
		address fromToken,
		uint256 amount,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt);
}

interface IQouter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

contract UniswapHelper is Tokens, Test {

    uint256 UNI_ROUTE = 1;
    string UNI_NAME = "SwapRouterV1";
    IQouter quoter = IQouter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    function getMulticalSwapData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns(bytes memory data) {
        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = getExactInputSingleData(_fromToken, _toToken, _recipient, _amount);

        data = abi.encodeWithSelector(IUni.multicall.selector, block.timestamp + 10 days, _calldata);
    }

    function getExactInputSingleData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory data) {

        _fromToken = _fromToken == ethC || _fromToken == ethC2 ? wethC : _fromToken;
        _toToken = _toToken == ethC || _toToken == ethC2 ? wethC : _toToken;

        IUni.ExactInputSingleParams memory params = IUni.ExactInputSingleParams(
            _fromToken,
            _toToken,
            500, // pool fee
            _recipient,
            _amount,
            0,
            0
        );

        data = abi.encodeWithSelector(IUni.exactInputSingle.selector, params); 
    }

     function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        amountOut = quoter.quoteExactInputSingle(tokenIn, tokenOut, 500, amountIn, 0);
    }

    function getSwapData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory _data) {
        bytes memory swapdata = getMulticalSwapData(_fromToken, _toToken, address(_recipient), _amount);
        _data = abi.encode(UNI_NAME,
            abi.encodeWithSelector(
                IUni.swap.selector, _toToken, _fromToken, _amount, UNI_ROUTE, swapdata
            )
        );
    }
}