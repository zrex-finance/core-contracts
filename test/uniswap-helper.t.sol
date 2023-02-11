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

abstract contract UniswapHelper {

    address ethC = 0x0000000000000000000000000000000000000000;
    address wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function getMulticalSwapData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns(bytes memory data) {
        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = getExactInputSingleData(_fromToken, _toToken, _recipient, _amount);

        data = abi.encodeWithSelector(IUni.multicall.selector, block.timestamp * 2, _calldata);
    }

    function getExactInputSingleData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory data) {
        IUni.ExactInputSingleParams memory params = IUni.ExactInputSingleParams(
            _fromToken == ethC ? wethC : _fromToken,
            _toToken == ethC ? wethC : _toToken,
            500, // pool fee
            _recipient,
            _amount,
            0,
            0
        );

        data = abi.encodeWithSelector(IUni.exactInputSingle.selector, params); 
    }
}
