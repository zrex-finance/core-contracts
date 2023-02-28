// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/UniversalERC20.sol";

import { Connector } from "./connector.sol";
import { FlashReceiver } from "./receiver.sol";

import "forge-std/Test.sol";

import { IExchanges, SharedStructs } from "./interfaces.sol";

contract PositionRouter is Connector {
    using UniversalERC20 for IERC20;

    uint256 public constant MAX_FEE = 500; // 5%
    uint256 private constant DENOMINATOR = 10000;

    uint256 public constant fee = 3;

    address private constant treasury = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    IExchanges private constant exchanges = IExchanges(0xa0Cb889707d426A7A386870A03bc70d1b0697598);
    FlashReceiver private constant flashReceiver = FlashReceiver(0x1d1499e622D69689cdf9004d05Ec547d650Ff211);

    mapping (bytes32 => SharedStructs.Position) public positions;
    mapping (address => uint256) public positionsIndex;

    mapping (address => PositionRouter) public users;

    modifier onlyCallback() {
        require(msg.sender == address(flashReceiver), "Access denied");
        _;
    }

    receive() external payable {}

    fallback() external payable {}

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
        
        // if (isShort) {
        //     (uint256 returnedAmt,,) = exchange(_customData, true);
        //     position.amountIn = returnedAmt;
        // } else {
        //     IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
        // }

        address account = position.account;
        uint256 index = positionsIndex[account] += 1;

        positionsIndex[account] = index;

        bytes32 key = getKey(account, index);
        positions[key] = position;

        flashReceiver.flashloan(_tokens, _amts, route, address(this), _data, _customData);

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

        flashReceiver.flashloan(_tokens, _amts, route,address(this), _data, _customData);

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
        console.log("openPositionCallback repayAmount", repayAmount);
        (uint256 value, address debt,/* address collateral */) = exchange(_datas[0], false);

        console.log("openPositionCallback value", value);

        deposit(value, _datas[1]);
        console.log("IERC20(debt) b", IERC20(debt).balanceOf(address(this)));
        borrow(repayAmount, _datas[2]);

        bytes32 key = bytes32(_customDatas[0]);
        

        positions[key].collateralAmount = value;
        positions[key].borrowAmount = repayAmount;

        console.log("IERC20(debt)", IERC20(debt).balanceOf(address(this)));
        
        IERC20(debt).transfer(address(flashReceiver), repayAmount);
    }

    function closePositionCallback(
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external payable onlyCallback {

        payback(_datas[0]);
        withdraw(_datas[1]);

        (uint256 returnedAmt, /* address collateral */,/* address debt */) = exchange(_datas[2], false);

        SharedStructs.Position memory position = positions[bytes32(_customDatas[0])];

        IERC20(position.debt).universalTransfer(address(flashReceiver), repayAmount);
        IERC20(position.debt).universalTransfer(position.account, returnedAmt - repayAmount);
    }

    function exchange(bytes memory _exchangeData, bool isTransfer) internal returns(uint256,address,address) {
        (
            address buyAddr,
            address sellAddr,
            uint256 sellAmt,
            uint256 _route,
            bytes memory callData
        ) = abi.decode(_exchangeData, (address, address, uint256, uint256, bytes));

        console.log("buyAddr", buyAddr);
        console.log("sellAddr", sellAddr);
        console.log("sellAmt", sellAmt);
        console.log("_route", _route);
        console.log("exchanges", address(exchanges));

        if (isTransfer) {
            IERC20(sellAddr).universalTransferFrom(msg.sender, address(this), sellAmt);
        }
        IERC20(sellAddr).universalApprove(address(exchanges), sellAmt);

        uint256 amt = IERC20(sellAddr).isETH() ? sellAmt : 0;
        uint256 value = exchanges.exchange{value: amt}(buyAddr, sellAddr, sellAmt, _route, callData);

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