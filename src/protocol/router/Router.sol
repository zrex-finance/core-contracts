// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Errors } from "../libraries/helpers/Errors.sol";
import { DataTypes } from "../libraries/types/DataTypes.sol";
import { PercentageMath } from "../libraries/math/PercentageMath.sol";
import { UniversalERC20 } from "../../libraries/tokens/UniversalERC20.sol";

import { IAccount } from "../../interfaces/IAccount.sol";
import { IConnectors } from "../../interfaces/IConnectors.sol";
import { IAddressesProvider } from "../../interfaces/IAddressesProvider.sol";

import { RouterStorage } from "./RouterStorage.sol";

contract Router is RouterStorage {
    using UniversalERC20 for IERC20;

    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    // will come as a parameter from the UI
    bytes32 public constant SALT = 0x0000000000000000000000000000000000000000000000000000000047941987;

    constructor(uint256 _fee, address _provider) {
        require(_provider != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
        fee = _fee;
        ADDRESSES_PROVIDER = IAddressesProvider(_provider);
    }

    function swapAndOpen(
        DataTypes.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data,
        DataTypes.SwapParams memory _params
    ) external payable {
        IERC20(_params.fromToken).universalTransferFrom(msg.sender, address(this), _params.amount);
        position.amountIn = _swap(_params);
        _openPosition(position, _token, _amount, _route, _data);
    }

    function openPosition(
        DataTypes.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) public payable {
        IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);
        _openPosition(position, _token, _amount, _route, _data);
    }

    function _openPosition(
        DataTypes.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) private {
        require(position.account == msg.sender, Errors.CALLER_NOT_POSITION_OWNER);

        address account = getOrCreateAccount(msg.sender);

        uint256 index = positionsIndex[position.account] += 1;
        positionsIndex[position.account] = index;

        bytes32 key = getKey(position.account, index);
        positions[key] = position;

        IERC20(position.debt).universalApprove(account, position.amountIn);
        IAccount(account).openPosition{ value: msg.value }(position, _token, _amount, _route, _data);
    }

    function closePosition(
        bytes32 key,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data
    ) external {
        DataTypes.Position memory position = positions[key];
        require(msg.sender == position.account, Errors.CALLER_NOT_POSITION_OWNER);

        address account = accounts[msg.sender];
        require(account != address(0), Errors.ACCOUNT_DOES_NOT_EXIST);

        IAccount(account).closePosition(key, _token, _amount, _route, _data);

        delete positions[key];
    }

    function updatePosition(DataTypes.Position memory position) public {
        require(msg.sender == accounts[position.account], Errors.CALLER_NOT_ACCOUNT_OWNER);

        bytes32 key = getKey(position.account, positionsIndex[position.account]);
        positions[key] = position;
    }

    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function getFeeAmount(uint256 _amount) public view returns (uint256 feeAmount) {
        require(_amount > 0, Errors.INVALID_AMOUNT);
        feeAmount = (_amount * fee) / PercentageMath.PERCENTAGE_FACTOR;
    }

    function getOrCreateAccount(address _owner) public returns (address) {
        require(_owner == msg.sender, Errors.CALLER_NOT_ACCOUNT_OWNER);
        address _account = address(accounts[_owner]);

        if (_account == address(0)) {
            _account = Clones.cloneDeterministic(ADDRESSES_PROVIDER.getAccountProxy(), SALT);
            accounts[_owner] = _account;
            IAccount(_account).initialize(_owner, address(ADDRESSES_PROVIDER));
        }

        return _account;
    }

    function predictDeterministicAddress() public view returns (address predicted) {
        return Clones.predictDeterministicAddress(ADDRESSES_PROVIDER.getAccountProxy(), SALT, address(this));
    }

    function _swap(DataTypes.SwapParams memory _params) private returns (uint256 value) {
        bytes memory response = execute(_params.targetName, _params.data);
        value = abi.decode(response, (uint256));
    }

    function execute(string memory _targetName, bytes memory _data) internal returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(ADDRESSES_PROVIDER.getConnectors()).isConnector(_targetName);
        require(isOk, Errors.NOT_CONNECTOR);
        response = _delegatecall(_target, _data);
    }

    function _delegatecall(address _target, bytes memory _data) internal returns (bytes memory response) {
        require(_target != address(0), Errors.INVALID_CONNECTOR_ADDRESS);
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
