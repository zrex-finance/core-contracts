// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "../../dependencies/openzeppelin/contracts/IERC20.sol";
import { Clones } from "../../dependencies/openzeppelin/upgradeability/Clones.sol";
import { Initializable } from "../../dependencies/openzeppelin/upgradeability/Initializable.sol";

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
 * @author FlashFlow
 * @notice Main point of interaction with an FlashFlow protocol
 * - Users can:
 *   # Open position
 *   # Close position
 *   # Swap their tokens
 *   # Create acconut
 */
contract Router is RouterStorage, Initializable {
    using UniversalERC20 for IERC20;

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /**
     * @dev Only pool configurator can call functions marked by this modifier.
     */
    modifier onlyRouterConfigurator() {
        require(ADDRESSES_PROVIDER.getRouterConfigurator() == msg.sender, Errors.CALLER_NOT_ROUTER_CONFIGURATOR);
        _;
    }

    /**
     * @dev Constructor.
     * @param provider The address of the AddressesProvider contract
     */
    constructor(address provider) {
        ADDRESSES_PROVIDER = IAddressesProvider(provider);
        fee = 3; // 0.3%
    }

    /**
     * @notice Initializes the Router.
     * @dev Function is invoked by the proxy contract when the Router contract is added to the
     * AddressesProvider.
     * @dev Caching the address of the AddressesProvider in order to reduce gas consumption on subsequent operations
     * @param provider The address of the AddressesProvider
     */
    function initialize(address provider) external virtual initializer {
        require(provider == address(ADDRESSES_PROVIDER), Errors.INVALID_ADDRESSES_PROVIDER);
    }

    /**
     * @dev Returns the future address of the account created through create2, necessary for the user interface.
     * @param _owner User account address, convert to salt.
     * @return predicted Returns of the user account address.
     */
    function predictDeterministicAddress(address _owner) public view returns (address predicted) {
        return
            Clones.predictDeterministicAddress(
                ADDRESSES_PROVIDER.getAccountProxy(),
                bytes32(abi.encodePacked(_owner)),
                address(this)
            );
    }

    /**
     * @dev Checks if the user has an account otherwise creates and initializes it.
     * @param _owner User address.
     * @return Returns of the user account address.
     */
    function getOrCreateAccount(address _owner) public returns (address) {
        require(_owner == msg.sender, Errors.CALLER_NOT_ACCOUNT_OWNER);
        address _account = address(accounts[_owner]);

        if (_account == address(0)) {
            _account = Clones.cloneDeterministic(
                ADDRESSES_PROVIDER.getAccountProxy(),
                bytes32(abi.encodePacked(_owner))
            );
            accounts[_owner] = _account;
            IAccount(_account).initialize(_owner, address(ADDRESSES_PROVIDER));
        }

        return _account;
    }

    /**
     * @dev Exchanges tokens and sends them to the sender, an auxiliary function for the user interface.
     * @param _params parameters required for the exchange.
     */
    function swap(DataTypes.SwapParams memory _params) public payable {
        uint256 initialBalance = IERC20(_params.toToken).balanceOf(address(this));
        uint256 value = _swap(_params);
        uint256 finalBalance = IERC20(_params.toToken).balanceOf(address(this));
        require(finalBalance - initialBalance == value, "value is not valid");

        IERC20(_params.toToken).universalTransferFrom(address(this), msg.sender, value);
    }

    /**
     * @dev Updates the current positions required for the callback.
     * @param _position The structure of the current position.
     */
    function updatePosition(DataTypes.Position memory _position) public {
        require(msg.sender == accounts[_position.account], Errors.CALLER_NOT_ACCOUNT_OWNER);

        bytes32 key = getKey(_position.account, positionsIndex[_position.account]);
        positions[key] = _position;
    }

    /**
     * @dev Create position key.
     * @param _account Position account owner.
     * @param _index Position count account owner.
     * @return Returns the position key
     */
    function getKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    /**
     * @dev Calculates and returns the current commission depending on the amount.
     * @param _amount Amount.
     * @return feeAmount Returns the protocol fee amount.
     */
    function getFeeAmount(uint256 _amount) public view returns (uint256 feeAmount) {
        require(_amount > 0, Errors.INVALID_CHARGE_AMOUNT);
        feeAmount = (_amount * fee) / PercentageMath.PERCENTAGE_FACTOR;
    }

    /**
     * @notice Set a new fee to the router contract.
     * @param _fee The new amount
     */
    function setFee(uint256 _fee) external onlyRouterConfigurator {
        require(_fee > 0, Errors.INVALID_FEE_AMOUNT);
        fee = _fee;
    }

    /**
     * @dev Exchanges the input token for the necessary token to create a position and opens it.
     * @param _position The structure of the current position.
     * @param _token Flashloan token.
     * @param _amount Flashloan amount.
     * @param _route The path chosen to take the loan See `FlashAggregator` contract.
     * @param _data Calldata for the openPositionCallback.
     * @param _params The additional parameters needed to the exchange.
     */
    function swapAndOpen(
        DataTypes.Position memory _position,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data,
        DataTypes.SwapParams memory _params
    ) external payable {
        _position.amountIn = _swap(_params);
        _openPosition(_position, _token, _amount, _route, _data);
    }

    /**
     * @dev Create a position on the lendings protocol.
     * @param _position The structure of the current position.
     * @param _token Flashloan token.
     * @param _amount Flashloan amount.
     * @param _route The path chosen to take the loan See `FlashAggregator` contract.
     * @param _data Calldata for the openPositionCallback.
     */
    function openPosition(
        DataTypes.Position memory _position,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data
    ) external payable {
        IERC20(_position.debt).universalTransferFrom(msg.sender, address(this), _position.amountIn);
        _openPosition(_position, _token, _amount, _route, _data);
    }

    /**
     * @dev Create user account if user doesn't have it. Update position index and position state.
     * Call openPosition on the user account proxy contract.
     */
    function _openPosition(
        DataTypes.Position memory _position,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data
    ) private {
        require(_position.account == msg.sender, Errors.CALLER_NOT_POSITION_OWNER);

        address account = getOrCreateAccount(msg.sender);

        uint256 index = positionsIndex[_position.account] += 1;
        positionsIndex[_position.account] = index;

        bytes32 key = getKey(_position.account, index);
        positions[key] = _position;

        IERC20(_position.debt).universalApprove(account, _position.amountIn);
        IAccount(account).openPosition{ value: msg.value }(_position, _token, _amount, _route, _data);
    }

    /**
     * @dev Сloses the user's position and deletes it.
     * @param _key The key to obtain the current position.
     * @param _token Flashloan token.
     * @param _amount Flashloan amount.
     * @param _route The path chosen to take the loan See `FlashAggregator` contract.
     * @param _data Calldata for the openPositionCallback.
     */
    function closePosition(
        bytes32 _key,
        address _token,
        uint256 _amount,
        uint16 _route,
        bytes calldata _data
    ) external {
        DataTypes.Position memory position = positions[_key];
        require(msg.sender == position.account, Errors.CALLER_NOT_POSITION_OWNER);

        address account = accounts[msg.sender];
        require(account != address(0), Errors.ACCOUNT_DOES_NOT_EXIST);

        IAccount(account).closePosition(_key, _token, _amount, _route, _data);

        delete positions[_key];
    }

    /**
     * @dev Internal function for the exchange, sends tokens to the current contract.
     * @param _params parameters required for the exchange.
     * @return value  Returns the amount of tokens received.
     */
    function _swap(DataTypes.SwapParams memory _params) private returns (uint256 value) {
        IERC20(_params.fromToken).universalTransferFrom(msg.sender, address(this), _params.amount);
        bytes memory response = execute(_params.targetName, _params.data);
        value = abi.decode(response, (uint256));
    }

    /**
     * @dev They will check if the target is a finite connector, and if it is, they will call it.
     * @param _targetName Name of the connector.
     * @param _data Execute calldata.
     * @return response Returns the result of calling the calldata.
     */
    function execute(string memory _targetName, bytes memory _data) private returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(ADDRESSES_PROVIDER.getConnectors()).isConnector(_targetName);
        require(isOk, Errors.NOT_CONNECTOR);
        response = _delegatecall(_target, _data);
    }

    /**
     * @dev Delegates the current call to `target`.
     * @param _target Name of the connector.
     * @param _data Execute calldata.
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegatecall(address _target, bytes memory _data) private returns (bytes memory response) {
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
