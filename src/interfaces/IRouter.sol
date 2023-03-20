// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DataTypes } from "../protocol/libraries/types/DataTypes.sol";

interface IRouter {
    function swapAndOpen(
        DataTypes.Position memory _position,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data,
        DataTypes.SwapParams memory _params
    ) external payable;

    function openPosition(
        DataTypes.Position memory _position,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data
    ) external payable;

    function fee() external returns (uint256);

    function setFee(uint256 _fee) external;

    function closePosition(bytes32 _key, address _token, uint256 _amount, uint16 _route, bytes calldata _data) external;

    function updatePosition(DataTypes.Position memory _position) external;

    function getKey(address _account, uint256 _index) external pure returns (bytes32);

    function getFeeAmount(uint256 _amount) external view returns (uint256 feeAmount);

    function getOrCreateAccount(address _owner) external returns (address);

    function predictDeterministicAddress() external view returns (address predicted);

    function positions(bytes32 _key) external returns (DataTypes.Position memory);

    function accounts(address _user) external returns (address);
}
