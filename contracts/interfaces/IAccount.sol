// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DataTypes } from '../lib/DataTypes.sol';
import { IAddressesProvider } from './IAddressesProvider.sol';

interface IAccount {
    function initialize(address _user, IAddressesProvider _provider) external;

    function openPosition(
        DataTypes.Position memory _position,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data
    ) external payable;

    function closePosition(bytes32 _key, address _token, uint256 _amount, uint16 _route, bytes calldata _data) external;

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

    function executeOperation(
        address[] calldata /* _tokens */,
        uint256[] calldata _amounts,
        uint256[] calldata _premiums,
        address _initiator,
        bytes calldata _params
    ) external returns (bool);

    function claimTokens(address _token, uint256 _amount) external;
}
