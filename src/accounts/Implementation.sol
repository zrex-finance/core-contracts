// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { IPositionRouter, SharedStructs, IConnectors } from "./interfaces/Implementation.sol";

contract Implementation is Initializable {
    using UniversalERC20 for IERC20;

    address private _owner;
    IPositionRouter private positionRouter;

    receive() external payable {}

    modifier onlyOwner() {
        require(_owner == msg.sender, "caller is not the owner or regesry");
        _;
    }

	function initialize(address _account, address _positionRouter) public initializer {
        _owner = _account;
        positionRouter = IPositionRouter(_positionRouter);
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
        if (isShort) {
			uint256 value = swap(_customData);
            position.amountIn = value;
		} else {
			IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
		}
        IERC20(position.debt).universalApprove(address(positionRouter), position.amountIn);

        positionRouter.openPosition{value: msg.value}(
			position, _tokens, _amts, route, _data, _customData
		);
    }

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external {
        positionRouter.closePosition(key, _tokens, _amts, route, _data, _customData);
    }

	function swap(bytes calldata _customdata) internal returns(uint256 value) {
        (address fromToken, uint256 amount) = getSwapData(_customdata);
        IERC20(fromToken).universalTransferFrom(msg.sender, address(this), amount);

        (string memory name, bytes memory _calldata) = abi.decode(_customdata, (string, bytes));
        (bool isConnector, address _target) = IConnectors(positionRouter.connectors()).isConnector(name);
        require(isConnector, "not connector");

        (bool success, bytes memory response) = _target.delegatecall(_calldata);
        require(success);
        value = abi.decode(response, (uint256));
    }

    function getSwapData(bytes calldata _customdata) private pure returns (address fromToken, uint256 amount) {
        (, bytes memory _swapdata) = abi.decode(_customdata, (string,bytes));

        (,,fromToken,amount,) = abi.decode(
            // https://github.com/ethereum/solidity/issues/6012
            abi.encodePacked(bytes28(0), _swapdata), (bytes32,address,address,uint256,bytes)
        );
    }
}