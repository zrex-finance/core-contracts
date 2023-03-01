// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExecutor {
    function execute(
        address[] calldata _targets,
        bytes[] calldata _datas,
        address _origin
    ) external payable;
}

interface IFlashLoan {
    function flashLoan(
        address[] memory tokens_,
        uint256[] memory amts_,
        uint256 route,
        bytes calldata data_,
        bytes calldata _customData
    ) external;
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
        address initiator,
        bytes calldata  params
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

library SharedStructs {
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 sizeDelta;
        uint256 collateralAmount;
        uint256 borrowAmount;
    }
}

interface IAccount {
    function openPosition(
        SharedStructs.Position memory position,
        bool isShort,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function initialize(address _positionRouter) external;
}

interface IPositionRouter {
    function openPosition(
        SharedStructs.Position memory position,
        bool isShort,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function closePosition(
        bytes32 key,
        address[] calldata _tokens,
        uint256[] calldata _amts,
        uint256 route,
        bytes calldata _data,
        bytes calldata _customData
    ) external payable;

    function positions(bytes32 _key) external pure returns (
        address account,
        address debt,
        address collateral,
        uint256 amountIn,
        uint256 sizeDelta,
        uint256 collateralAmount,
        uint256 borrowAmount
    );
    function positionsIndex(address _account) external pure returns (uint256);
    function getKey(address _account, uint256 _index) external pure returns (bytes32);

    function initialize(
        address _flashloanAggregator,
        address _exchanges,
        uint256 _fee,
        address _treasury,
        address _euler,
        address _aaveV2Resolver,
        address _compoundV3Resolver
    ) external;

    function openPositionCallback(
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 repayAmount
    ) external;
}

interface IImplimentation {
    function execute(
		address[] memory _targets,
		bytes[] memory _datas,
		address _origin
	) external;
}