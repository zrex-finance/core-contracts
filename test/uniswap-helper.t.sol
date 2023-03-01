// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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

abstract contract UniswapHelper {

    address ethC = 0x0000000000000000000000000000000000000000;
    address ethC2 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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
        IUni.ExactInputSingleParams memory params = IUni.ExactInputSingleParams(
            _fromToken == ethC || _fromToken == ethC2 ? wethC : _fromToken,
            _toToken == ethC || _toToken == ethC2 ? wethC : _toToken,
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
}
