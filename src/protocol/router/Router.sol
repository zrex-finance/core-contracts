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

/**
 * @title Router contract
 * @author FlasFlow
 * @notice Main point of interaction with an FlashFlow protocol
 * - Users can:
 *   # Open position
 *   # Close position
 *   # Swap their tokens
 *   # Create acconut
 */
contract Router is RouterStorage {
    using UniversalERC20 for IERC20;

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    // will come as a parameter from the UI
    bytes32 public constant SALT = 0x0000000000000000000000000000000000000000000000000000000047941987;

    /**
     * @dev Constructor.
     * @param uint256 Fee of the protocol.
     * @param address The address of the AddressesProvider contract.
     */
    constructor(uint256 _fee, address _provider) {
        require(_provider != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
        fee = _fee;
        ADDRESSES_PROVIDER = IAddressesProvider(_provider);
    }

    /**
     * @dev Exchanges the input token for the necessary token to create a position and opens it.
     * @param Position The structure of the current position.
     * @param address Flashloan token.
     * @param uint256 Flashloan amount.
     * @param uint256 The path chosen to take the loan See `FlashAggregator` contract.
     * @param bytes Calldata for the openPositionCallback.
     * @param SwapParams The additional parameters needed to the exchange.
     */
    function swapAndOpen(
        DataTypes.Position memory position,
        address _token,
        uint256 _amount,
        uint256 _route,
        bytes calldata _data,
        DataTypes.SwapParams memory _params
    ) external payable {
        position.amountIn = _swap(_params);
        _openPosition(position, _token, _amount, _route, _data);
    }

    /**
     * @dev Create a position on the lendings protocol and save it.
     * @param Position The structure of the current position.
     * @param address Flashloan token.
     * @param uint256 Flashloan amount.
     * @param uint256 The path chosen to take the loan See `FlashAggregator` contract.
     * @param bytes Calldata for the openPositionCallback.
     */
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

    /**
     * @dev Create a position on the lendings protocol and save it.
     */
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

    /**
     * @dev Сloses the user's position and deletes it.
     * @param bytes32 The key to obtain the current position.
     * @param address Flashloan token.
     * @param uint256 Flashloan amount.
     * @param uint256 The path chosen to take the loan See `FlashAggregator` contract.
     * @param bytes Calldata for the openPositionCallback.
     */
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

    /**
     * @dev Updates the current positions required for the callback.
     * @param Position The structure of the current position.
     */
    function updatePosition(DataTypes.Position memory position) public {
        require(msg.sender == accounts[position.account], Errors.CALLER_NOT_ACCOUNT_OWNER);

        bytes32 key = getKey(position.account, positionsIndex[position.account]);
        positions[key] = position;
    }

    /**
     * @dev Create position key.
     * @param address Position account owner.
     * @param uint256 Position count account owner.
     * @return Returns the position key
     */
    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    /**
     * @dev Calculates and returns the current commission depending on the amount.
     * @param uint256 Amount.
     * @return Returns the protocol fee amount.
     */
    function getFeeAmount(uint256 _amount) public view returns (uint256 feeAmount) {
        require(_amount > 0, Errors.INVALID_AMOUNT);
        feeAmount = (_amount * fee) / PercentageMath.PERCENTAGE_FACTOR;
    }

    /**
     * @dev Checks if the user has an account otherwise creates and initializes it.
     * @param address User address.
     * @return Returns of the user account address.
     */
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

    /**
     * @dev Returns the future address of the account created through create2, necessary for the user interface.
     * @param address User address.
     * @return Returns of the user account address.
     */
    function predictDeterministicAddress() public view returns (address predicted) {
        return Clones.predictDeterministicAddress(ADDRESSES_PROVIDER.getAccountProxy(), SALT, address(this));
    }

    /**
     * @dev Exchanges tokens and sends them to the sender, an auxiliary function for the user interface.
     * @param SwapParams parameters required for the exchange.
     */
    function swap(DataTypes.SwapParams memory _params) public payable {
        uint256 initialBalance = IERC20(_params.toToken).balanceOf(address(this));
        uint256 value = _swap(_params);
        uint256 finalBalance = IERC20(_params.toToken).balanceOf(address(this));
        require(finalBalance - initialBalance == value, "value is not valid");

        IERC20(_params.toToken).universalTransferFrom(address(this), msg.sender, value);
    }

    /**
     * @dev Internal function for the exchange, sends tokens to the current contract.
     * @param SwapParams parameters required for the exchange.
     * @return Returns the amount of tokens received.
     */
    function _swap(DataTypes.SwapParams memory _params) private returns (uint256 value) {
        IERC20(_params.fromToken).universalTransferFrom(msg.sender, address(this), _params.amount);
        bytes memory response = execute(_params.targetName, _params.data);
        value = abi.decode(response, (uint256));
    }

    /**
     * @dev They will check if the target is a finite connector, and if it is, they will call it.
     * @param string Name of the connector.
     * @param bytes Execute calldata.
     * @return Returns the result of calling the calldata.
     */
    function execute(string memory _targetName, bytes memory _data) internal returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(ADDRESSES_PROVIDER.getConnectors()).isConnector(_targetName);
        require(isOk, Errors.NOT_CONNECTOR);
        response = _delegatecall(_target, _data);
    }

    /**
     * @dev Delegates the current call to `target`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
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
