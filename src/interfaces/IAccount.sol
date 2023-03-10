// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DataTypes } from "../protocol/libraries/types/DataTypes.sol";

interface IAccount {
    function flashLoan(
        address[] memory tokens_,
        uint256[] memory amts_,
        uint256 _route,
        bytes calldata _data,
        bytes calldata _customData
    ) external;

    function initialize(address _user, address _provider) external;

    function openPosition(
        DataTypes.Position memory position,
        address _token,
        uint256 _amount,
        uint256 route,
        bytes calldata _data
    ) external payable;

    function closePosition(bytes32 _key, address _token, uint256 _amount, uint256 route, bytes calldata _data) external;

    function openPositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 _repayAmount
    ) external payable;

    function closePositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 _repayAmount
    ) external payable;

    function flashloan(address _token, uint256 _amount, uint256 route, bytes calldata _data) external;

    function executeOperation(
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        uint256[] calldata _premiums,
        address _initiator,
        bytes calldata _params
    ) external returns (bool);
}
