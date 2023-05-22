// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { IQuoter } from 'contracts/interfaces/external/uniswap-v3/IQuoter.sol';
import { IAutoRouter } from 'contracts/interfaces/external/uniswap-v3/IAutoRouter.sol';
import { IUniswapV3Pool } from 'contracts/interfaces/external/uniswap-v3/IUniswapV3Pool.sol';
import { IUniswapV3Factory } from 'contracts/interfaces/external/uniswap-v3/IUniswapV3Factory.sol';

contract Tokens {
    // address usdcC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address usdcC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address usdtC = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // address daiC = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address ethC = 0x0000000000000000000000000000000000000000;
    address ethC2 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    // address wethC = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address comp = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
}

contract UniswapHelper is Tokens, Test {
    string UNI_NAME = 'UniswapAuto';

    IUniswapV3Factory internal constant UNISWAP_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    IQuoter internal constant QUOTER = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    function getMulticalSwapData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory data) {
        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = getExactInputData(_fromToken, _toToken, _recipient, _amount, 0);
        data = abi.encodeWithSelector(IAutoRouter.multicall.selector, block.timestamp + 10 days, _calldata);
    }

    function getExactInputData(
        address _tokenIn,
        address _tokenOut,
        address _recipient,
        uint256 _amountIn,
        uint256 _minReceiveAmount
    ) public view returns (address, uint256, bytes memory) {
        bytes memory path = _getPath(_tokenIn, _tokenOut, address(0));
        IAutoRouter.ExactInputParams memory params = IAutoRouter.ExactInputParams(
            path,
            _recipient,
            _amountIn,
            _minReceiveAmount
        );

        data = abi.encodeWithSelector(IAutoRouter.exactInput.selector, params);
    }

    function quoteExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _hopToken
    ) public returns (uint256 amountOut) {
        bytes memory path = _getPath(_tokenIn, _tokenOut, _hopToken);
        amountOut = QUOTER.quoteExactInput(path, _amountIn);
    }

    function _getPath(address _tokenIn, address _tokenOut, address _hopToken) private view returns (bytes memory path) {
        if (_hopToken == address(0) || _tokenIn == _hopToken || _tokenOut == _hopToken) {
            (, uint24 fee) = _getUniswapPool(_tokenIn, _tokenOut);
            path = abi.encodePacked(_tokenIn, fee, _tokenOut);
        } else {
            (, uint24 fee0) = _getUniswapPool(_tokenIn, _hopToken);
            (, uint24 fee1) = _getUniswapPool(_tokenOut, _hopToken);
            path = abi.encodePacked(_tokenIn, fee0, _hopToken, fee1, _tokenOut);
        }
    }

    function _getUniswapPool(
        address _tokenIn,
        address _tokenOut
    ) private view returns (IUniswapV3Pool pool, uint24 fee) {
        IUniswapV3Pool poolLow = IUniswapV3Pool(UNISWAP_FACTORY.getPool(_tokenIn, _tokenOut, FEE_LOW));
        IUniswapV3Pool poolMedium = IUniswapV3Pool(UNISWAP_FACTORY.getPool(_tokenIn, _tokenOut, FEE_MEDIUM));
        IUniswapV3Pool poolHigh = IUniswapV3Pool(UNISWAP_FACTORY.getPool(_tokenIn, _tokenOut, FEE_HIGH));

        uint128 liquidityLow = address(poolLow) != address(0) ? poolLow.liquidity() : 0;
        uint128 liquidityMedium = address(poolMedium) != address(0) ? poolMedium.liquidity() : 0;
        uint128 liquidityHigh = address(poolHigh) != address(0) ? poolHigh.liquidity() : 0;
        if (liquidityLow > liquidityMedium && liquidityLow >= liquidityHigh) {
            return (poolLow, FEE_LOW);
        }
        if (liquidityMedium > liquidityLow && liquidityMedium >= liquidityHigh) {
            return (poolMedium, FEE_MEDIUM);
        }
        return (poolHigh, FEE_HIGH);
    }

    function getUniSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory _data) {
        _data = getMulticalSwapData(_fromToken, _toToken, address(_recipient), _amount);
    }
}
