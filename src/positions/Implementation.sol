// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { Executor } from "./Executor.sol";
import { FlashReceiver } from "./FlashReceiver.sol";
import { IPositionRouter, SharedStructs, IConnectors } from "./interfaces/Implementation.sol";

contract Implementation is Executor, FlashReceiver {
    using UniversalERC20 for IERC20;

    address private _owner;
    IPositionRouter private positionRouter;

    receive() external payable {}

    modifier onlyOwner() {
        require(_owner == msg.sender, "caller is not the owner or regesry");
        _;
    }

    modifier onlyCallback() {
        require(msg.sender == address(this), "Access denied");
        _;
    }

    function initialize(
        address _account,
        address _connectors,
        address _positionRouter,
        address _flashloanAggregator
    ) public initializer {
        _owner = _account;
        __Executor_init(_connectors);
        __FlashReceiver_init(_flashloanAggregator);
        positionRouter = IPositionRouter(_positionRouter);
    }

    function openPosition(
        SharedStructs.Position memory position,
        address _token,
        uint256 _amount,
        uint256 route,
        bytes calldata _data
    ) external payable {
        require(position.account == _owner, "not owner");
        IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);

        flashloan(_token, _amount, route, _data);

        require(chargeFee(position.amountIn + _amount, position.debt), "transfer fee");
    }

    function closePosition(
        bytes32 _key,
        address _token,
        uint256 _amount,
        uint256 route,
        bytes calldata _data
    ) external {
        SharedStructs.Position memory position = positionRouter.positions(_key);
        require(position.account == _owner, "only own position");

        flashloan(_token, _amount, route, _data);
    }

    function openPositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external payable onlyCallback {
        uint256 value = _swap(_targetNames[0], _datas[0]);

        execute(_targetNames[1], abi.encodePacked(_datas[1], value));
        execute(_targetNames[1], abi.encodePacked(_datas[2], repayAmount));

        SharedStructs.Position memory position = getPosition(bytes32(_customDatas[0]));

        position.collateralAmount = value;
        position.borrowAmount = repayAmount;

        positionRouter.updatePosition(position);

        IERC20(position.debt).transfer(address(flashloanAggregator), repayAmount);
    }

    function getPosition(bytes32 _key) private returns (SharedStructs.Position memory) {
        SharedStructs.Position memory position = positionRouter.positions(_key);
        require(position.account == _owner, "only own position");
        return position;
    }

    function closePositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external payable onlyCallback {
        execute(_targetNames[0], _datas[0]);
        execute(_targetNames[1], _datas[1]);

        uint256 returnedAmt = _swap(_targetNames[2], _datas[2]);

        SharedStructs.Position memory position = getPosition(bytes32(_customDatas[0]));

        IERC20(position.debt).universalTransfer(address(flashloanAggregator), repayAmount);
        IERC20(position.debt).universalTransfer(position.account, returnedAmt - repayAmount);
    }

    function _swap(string memory _name, bytes memory _data) internal returns (uint256 value) {
        bytes memory response = execute(_name, _data);
        value = abi.decode(response, (uint256));
    }

    function chargeFee(uint256 _amount, address _token) internal returns (bool) {
        uint256 feeAmount = positionRouter.getFeeAmount(_amount);

        if (feeAmount <= 0) {
            return false;
        }

        return IERC20(_token).universalTransfer(positionRouter.treasury(), feeAmount);
    }
}
