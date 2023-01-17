// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExecutor {
    function execute(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin
    ) external payable;
}


contract PositionsRouter {
    struct Position {
        address account;
        address debt;
        address collateral;
        uint256 amountIn;
        uint256 sizeDelta;
    }

    IExecutor private immutable executor;

    mapping (bytes32 => Position) public positions;
    mapping (address => uint256) public positionsIndex;

    modifier onlyCallback() {
        require(msg.sender == address(this), "Access denied");
        _;
    }

    constructor(IExecutor _executor) {
        executor = _executor;
    }

    function openPosition(Position memory position) external payable {
        require(position.account == msg.sender, "Only owner");

        address account = position.account;
        uint256 index = positionsIndex[account] += 1;
        positionsIndex[account] = index;

        bytes32 key = getKey(position.account, index);

        positions[key] = position;
    }

    function closePosition(bytes32 key) external payable {
        Position memory position = positions[key];

        require(msg.sender == position.account, "Can close own position or position available for liquidation");

        delete positions[key];
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function openPositionCallback(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin,
        uint256 /* repayAmount */
    ) external payable onlyCallback {
        executor.execute(_targetNames, _datas, _origin);
    }

    function closePositionCallback(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin,
        uint256 /* repayAmount */
    ) external payable onlyCallback {
        executor.execute(_targetNames, _datas, _origin);

    }
}