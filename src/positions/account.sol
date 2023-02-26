// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../lib/UniversalERC20.sol";

import { CloneFactory } from "./proxy.sol";
import { IPositionRouter, SharedStructs } from "./interfaces.sol";

import "forge-std/Test.sol";

contract Accounts is CloneFactory, Test {
    using UniversalERC20 for IERC20;

    IPositionRouter private immutable positionRouter;

    address flashloanAggregator;
    address exchanges;
    uint256 fee;
    address treasury;
    address euler;
    address aaveV2Resolver;
    address compoundV3Resolver;

    mapping (address => IPositionRouter) public routers;

    receive() external payable {}
    fallback() external payable {}

    constructor(
        address _positionRouter,
        address _flashloanAggregator,
        address _exchanges,
        uint256 _fee,
        address _treasury,
        address _euler,
        address _aaveV2Resolver,
        address _compoundV3Resolver
    ) {
        positionRouter = IPositionRouter(_positionRouter);
        flashloanAggregator = _flashloanAggregator;
        exchanges = _exchanges;
        fee = _fee;
        treasury = _treasury;
        euler = _euler;
        aaveV2Resolver = _aaveV2Resolver;
        compoundV3Resolver = _compoundV3Resolver;
    }

    function openPosition(
        SharedStructs.Position memory position,
        bool isShort,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        if (!isShort) IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);

        IPositionRouter router = getOrCreateRouter(msg.sender);

        IERC20(position.debt).universalApprove(address(router), type(uint256).max);

        position.account = address(router);

        router.openPosition{value: msg.value}(position, isShort, _tokens, _amts, route, _data, _customData);
    }

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        IPositionRouter router = routers[msg.sender];

        require(address(router) != address(0), "first create router");

        router.closePosition(key, _tokens, _amts, route, _data, _customData);
    }

    function getOrCreateRouter(address _user) public returns (IPositionRouter) {
        address router = address(routers[_user]);

        if(address(0) == router) {
            router = Clones.clone(address(positionRouter));
            IPositionRouter(router).initialize(
                flashloanAggregator,
                exchanges,
                fee,
                treasury,
                euler,
                aaveV2Resolver,
                compoundV3Resolver
            );
            routers[_user] = IPositionRouter(router);
        }
        return IPositionRouter(router);
    }
}