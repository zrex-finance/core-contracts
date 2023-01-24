// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExecutor {
    function execute(
        address[] calldata _targets,
        bytes[] calldata _datas,
        address _origin
    ) external payable;
}

interface IFlashloanReciever {
    function flashloan(
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external;

    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        bytes calldata /* params */
    ) external returns (bool);
}

interface IExchanges {
    function exchange(
        address buyAddr,
		address sellAddr,
		uint256 sellAmt,
        uint256 _route,
		bytes calldata callData
    ) external payable returns (uint256 _buyAmt);
}