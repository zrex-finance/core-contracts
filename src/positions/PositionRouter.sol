// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/UniversalERC20.sol";

import { Connector } from "./connector.sol";
import { FlashReceiver } from "./receiver.sol";

import "forge-std/Test.sol";

import { IExchanges, SharedStructs } from "./interfaces.sol";

contract PositionRouter is Connector, FlashReceiver {
    using UniversalERC20 for IERC20;

    uint256 public constant MAX_FEE = 500; // 5%
    uint256 private constant DENOMINATOR = 10000;

    uint256 public fee;
    address private treasury;
    IExchanges private exchanges;

    mapping (bytes32 => SharedStructs.Position) public positions;
    mapping (address => uint256) public positionsIndex;

    mapping (address => PositionRouter) public users;

    modifier onlyCallback() {
        require(msg.sender == address(this), "Access denied");
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    constructor(
        address _flashloanAggregator,
        address _exchanges,
        uint256 _fee,
        address _treasury,
        address _euler,
        address _aaveV2Resolver,
        address _compoundV3Resolver
    ) FlashReceiver(_flashloanAggregator) Connector(_euler, _aaveV2Resolver, _compoundV3Resolver)  {
        require(_fee <= MAX_FEE, "Invalid fee"); // max fee 5%

        exchanges = IExchanges(_exchanges);
        fee = _fee;
        treasury = _treasury;
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
        require(position.account == msg.sender, "Only owner");
        
        if (isShort) {
            (uint256 returnedAmt,,) = exchange(_customData);
            position.amountIn = returnedAmt;
        } else {
            IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
        }

        address account = position.account;
        uint256 index = positionsIndex[account] += 1;

        positionsIndex[account] = index;

        bytes32 key = getKey(account, index);
        positions[key] = position;

        flashloan(_tokens, _amts, route, _data, _customData);

        require(
            chargeFee(position.amountIn + _amts[0], position.debt), 
            "transfer fee"
        );
    }

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable {
        SharedStructs.Position memory position = positions[key];

        require(msg.sender == position.account, "Can close own position");

        flashloan(_tokens, _amts, route, _data, _customData);

        delete positions[key];
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function openPositionCallback(
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external payable onlyCallback {
        (uint256 value, address debt,/* address collateral */) = exchange(_datas[0]);

        deposit(value, _datas[1]);
        borrow(repayAmount, _datas[2]);

        bytes32 key = bytes32(_customDatas[0]);
        

        positions[key].collateralAmount = value;
        positions[key].borrowAmount = repayAmount;
        
        IERC20(debt).transfer(address(flashloanAggregator), repayAmount);
    }

    function closePositionCallback(
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external payable onlyCallback {

        payback(_datas[0]);
        withdraw(_datas[1]);

        console.log("CLOSE");
        SharedStructs.Position memory position = positions[bytes32(_customDatas[0])];

        (uint256 returnedAmt, /* address collateral */,/* address debt */) = exchange(_datas[2]);

        IERC20(position.debt).universalTransfer(address(flashloanAggregator), repayAmount);
        IERC20(position.debt).universalTransfer(position.account, returnedAmt - repayAmount);
    }

    function exchange(bytes memory _exchangeData) internal returns(uint256,address,address) {
        (
            address buyAddr,
            address sellAddr,
            uint256 sellAmt,
            uint256 _route,
            bytes memory callData
        ) = abi.decode(_exchangeData, (address, address, uint256, uint256, bytes));

        (bool success, bytes memory response) = address(exchanges).delegatecall(
            abi.encodeWithSelector(exchanges.exchange.selector, buyAddr, sellAddr, sellAmt, _route, callData)
        );
        require(success);

        uint256 value = abi.decode(response, (uint256));

        return (value, sellAddr, buyAddr);
    }

    function chargeFee(uint256 _amt, address _token) internal returns (bool) {
        uint256 feeAmount = (_amt * fee) / DENOMINATOR;

        if (feeAmount <= 0) {
            return false;
        }

        return IERC20(_token).universalTransfer(treasury, feeAmount);
    }
}