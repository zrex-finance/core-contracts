// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/UniversalERC20.sol";
import "../executor/main.sol";

import "./interfaces.sol";

contract PositionRouter is Executor {
    using UniversalERC20 for IERC20;
    
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 sizeDelta;
    }

    IExchanges private immutable exchanges;
    IFlashloanReciever private immutable flashloanReciever;

    mapping (bytes32 => Position) public positions;
    mapping (address => uint256) public positionsIndex;

    modifier onlyCallback() {
        require(msg.sender == address(flashloanReciever), "Access denied");
        _;
    }

    receive() external payable {}

    constructor(IFlashloanReciever _flashloanReciever,IExchanges _exchanges) {
        flashloanReciever = _flashloanReciever;
        exchanges = _exchanges;
    }

    function openPosition(
        Position memory position,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        require(position.account == msg.sender, "Only owner");
        IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);

        flashloanReciever.flashloan(_tokens, _amts, route, _data, _customData);

        address account = position.account;
        uint256 index = positionsIndex[account] += 1;
        positionsIndex[account] = index;

        bytes32 key = getKey(position.account, index);

        positions[key] = position;
    }

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        Position memory position = positions[key];

        require(msg.sender == position.account, "Can close own position or position available for liquidation");

        flashloanReciever.flashloan(_tokens, _amts, route, _data, _customData);

        delete positions[key];
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function openPositionCallback(
        address[] calldata _targets,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        address _origin,
        uint256 repayAmount
    ) external payable onlyCallback {
        uint256 amt = exchange(_customDatas[0]);

        (bytes4 deposit, address collateral) = abi.decode(_datas[0], (bytes4, address));
        _datas[0] = abi.encodeWithSelector(deposit, collateral, amt);

        (bytes4 borrow, address debt) = abi.decode(_datas[1], (bytes4, address));
        _datas[1] = abi.encodeWithSelector(borrow, debt, repayAmount);

        execute(_targets, _datas, _origin);

        IERC20(debt).universalTransfer(address(flashloanReciever), repayAmount);
    }

    function closePositionCallback(
        address[] calldata _targets,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        address _origin,
        uint256 repayAmount
    ) external payable onlyCallback {
        execute(_targets, _datas, _origin);

        uint256 returnedAmt = exchange(_customDatas[0]);

        Position memory position = positions[bytes32(_customDatas[1])];

        IERC20(position.debt).universalTransfer(position.account, returnedAmt - repayAmount);
    }

    function exchange(bytes memory _exchangeData) internal returns (uint256 value) {
        (
            address buyAddr,
            address sellAddr,
            uint256 sellAmt,
            uint256 _route,
            bytes memory callData
        ) = abi.decode(_exchangeData, (address, address, uint256, uint256, bytes));

        IERC20(sellAddr).universalTransfer(address(exchanges), sellAmt);

        value = exchanges.exchange(buyAddr, sellAddr, sellAmt, _route, callData);
    }
}