// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SharedStructs } from "../lib/SharedStructs.sol";
import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { IAccount, IConnectors } from "./interfaces/PositionRouter.sol";

contract PositionRouter {
    using UniversalERC20 for IERC20;

    uint256 private constant MAX_FEE = 500; // 5%
    uint256 private constant DENOMINATOR = 10000;

    uint256 public fee;
    address public treasury;
    address public accountProxy;

    address public connectors;
    address public flashloanAggregator;

    bytes32 public constant salt = 0x0000000000000000000000000000000000000000000000000000000047941987; 

    mapping (address => uint256) public positionsIndex;
    mapping (bytes32 => SharedStructs.Position) public positions;

    // user -> account proxy
    mapping (address => address) public accounts;

    receive() external payable {}
    fallback() external payable {}

    constructor(
        address _flashloanAggregator,
        address _connectors,
        address _accountProxy,
        uint256 _fee,
        address _treasury
    ) {
        require(_fee <= MAX_FEE, "Invalid fee"); // max fee 5%

        flashloanAggregator = _flashloanAggregator; 
        connectors = _connectors; 
        accountProxy = _accountProxy; 
        fee = _fee;
        treasury = _treasury;
    }

    function swapAndOpen(
        SharedStructs.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data,
        SharedStructs.SwapParams memory _params
    ) external payable {
        position.amountIn = swap(_params);
        _openPosition(position, _token, _amount, _route, _data);
    }

    function openPosition(
        SharedStructs.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) public payable {
        IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
        _openPosition(position, _token, _amount, _route, _data);
    }

    function _openPosition(
        SharedStructs.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) private {
        require(position.account == msg.sender, "Only owner");

        address account = getOrCreateAccount(msg.sender);

        uint256 index = positionsIndex[position.account] += 1;
        positionsIndex[position.account] = index;

        bytes32 key = getKey(position.account, index);
        positions[key] = position;

        IERC20(position.debt).universalApprove(account, position.amountIn);
        IAccount(account).openPosition{value: msg.value}(position, _token, _amount, _route, _data);
    }

    function closePosition(
        bytes32 key,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) external {
        SharedStructs.Position memory position = positions[key];
        require(msg.sender == position.account, "can close own position");

        address account = accounts[msg.sender];
        require(account != address(0), "account doesnt exist");

        IAccount(account).closePosition(key, _token, _amount, _route, _data);

        delete positions[key];
    }

    function updatePosition(SharedStructs.Position memory position) public {
        require(msg.sender == accounts[position.account], "Can close own position");

        bytes32 key = getKey(position.account, positionsIndex[position.account]);
        positions[key] = position;
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function getFeeAmount(uint256 _amount) public view returns (uint256 feeAmount) {
        feeAmount = (_amount * fee) / DENOMINATOR;
    }

    function getOrCreateAccount(address _owner) public returns (address) {
        require(_owner == msg.sender, "sender not owner");
        address _account = address(accounts[_owner]);

        if (_account == address(0)) {
            _account = Clones.cloneDeterministic(accountProxy, salt);
            IAccount(_account).initialize(
                _owner,
                connectors,
                address(this),
                flashloanAggregator
            );
            accounts[_owner] = _account;
        }

        return _account;
    }

    function predictDeterministicAddress() public view returns (address predicted) {
        return Clones.predictDeterministicAddress(accountProxy, salt, address(this));
    }

    function swap(SharedStructs.SwapParams memory _params) public returns (uint256 value) {
        IERC20(_params.fromToken).universalTransferFrom(msg.sender, address(this), _params.amount);
        bytes memory response = execute(_params.targetName, _params.data);
        value = abi.decode(response, (uint256));
    }

    function execute(string memory _targetName, bytes memory _data) internal returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(connectors).isConnector(_targetName);
        require(isOk, "not connector");
        response = _delegatecall(_target, _data);
    }

    function _delegatecall(
		address _target,
		bytes memory _data
	) internal returns (bytes memory response) {
		require(_target != address(0), "Target invalid");
		assembly {
			let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)
			let size := returndatasize()

			response := mload(0x40)
			mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
			mstore(response, size)
			returndatacopy(add(response, 0x20), 0, size)

			switch iszero(succeeded)
			case 1 {
				// throw if delegatecall failed
				returndatacopy(0x00, 0x00, size)
				revert(0x00, size)
			}
		}
	}
}