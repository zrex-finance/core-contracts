// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { Errors } from "../libraries/helpers/Errors.sol";
import { DataTypes } from "../libraries/types/DataTypes.sol";
import { UniversalERC20 } from "../../libraries/tokens/UniversalERC20.sol";

import { IRouter } from "../../interfaces/IRouter.sol";
import { IConnectors } from "../../interfaces/IConnectors.sol";
import { IFlashAggregator } from "../../interfaces/IFlashAggregator.sol";
import { IAddressesProvider } from "../../interfaces/IAddressesProvider.sol";

/**
 * @title Account
 * @author FlashFlow
 * @notice Contract used as implimentation user account.
 * @dev Interaction with contracts is carried out by means of calling the proxy contract.
 */
contract Account is Initializable {
    using UniversalERC20 for IERC20;

    address private _owner;

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public ADDRESSES_PROVIDER;

    receive() external payable {}

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, Errors.CALLER_NOT_ACCOUNT_OWNER);
        _;
    }

    /**
     * @dev Throws if called by any account other than the current contract.
     */
    modifier onlyCallback() {
        require(msg.sender == address(this), Errors.CALLER_NOT_RECEIVER);
        _;
    }

    /**
     * @dev Throws if called by any account other than the flashloan aggregator contract.
     */
    modifier onlyAggregator() {
        require(msg.sender == ADDRESSES_PROVIDER.getFlashloanAggregator(), Errors.CALLER_NOT_FLASH_AGGREGATOR);
        _;
    }

    /**
     * @dev initialize.
     * @param address Owner account address.
     * @param IAddressesProvider The address of the AddressesProvider contract.
     */
    function initialize(address _user, IAddressesProvider _provider) public initializer {
        require(address(_provider) != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
        ADDRESSES_PROVIDER = _provider;
        _owner = _user;
    }

    /**
     * @dev Takes a loan, calls `openPositionCallback` inside the loan, and transfers the commission.
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
        uint256 route,
        bytes calldata _data
    ) external payable {
        require(position.account == _owner, Errors.CALLER_NOT_POSITION_OWNER);
        IERC20(position.debt).universalTransferFrom(msg.sender, address(this), position.amountIn);

        flashloan(_token, _amount, route, _data);

        require(chargeFee(position.amountIn + _amount, position.debt), Errors.CHARGE_FEE_NOT_COMPLETED);
    }

    /**
     * @dev Takes a loan, calls `closePositionCallback` inside the loan.
     * @param bytes32 The key to obtain the current position.
     * @param address Flashloan token.
     * @param uint256 Flashloan amount.
     * @param uint256 The path chosen to take the loan See `FlashAggregator` contract.
     * @param bytes Calldata for the openPositionCallback.
     */
    function closePosition(
        bytes32 _key,
        address _token,
        uint256 _amount,
        uint256 route,
        bytes calldata _data
    ) external {
        DataTypes.Position memory position = getRouter().positions(_key);
        require(position.account == _owner, Errors.CALLER_NOT_POSITION_OWNER);

        flashloan(_token, _amount, route, _data);
    }

    /**
     * @dev Is called via the caldata within a flashloan.
     * - Swap poisition debt token to collateral token.
     * - Deposit collateral token to the lending protocol.
     * - Borrow debt token to repay flashloan.
     * @param string The connector name that will be called are.
     * @param bytes Calldata needed to work with the connector `_datas and _targetNames must be with the same index`.
     * @param bytes Additional parameters for future use.
     * @param uint256 The amount needed to repay the flashloan.
     */
    function openPositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 _repayAmount
    ) external payable onlyCallback {
        uint256 value = _swap(_targetNames[0], _datas[0]);
        execute(_targetNames[1], abi.encodePacked(_datas[1], value));
        execute(_targetNames[1], abi.encodePacked(_datas[2], _repayAmount));
        DataTypes.Position memory position = getPosition(bytes32(_customDatas[0]));

        position.collateralAmount = value;
        position.borrowAmount = _repayAmount;

        getRouter().updatePosition(position);
        IERC20(position.debt).transfer(ADDRESSES_PROVIDER.getFlashloanAggregator(), _repayAmount);
    }

    /**
     * @dev Returns the position for the owner.
     * @param bytes32 The key to obtain the current position.
     * @return The structure of the current position.
     */
    function getPosition(bytes32 _key) private returns (DataTypes.Position memory) {
        DataTypes.Position memory position = getRouter().positions(_key);
        require(position.account == _owner, Errors.CALLER_NOT_POSITION_OWNER);
        return position;
    }

    /**
     * @dev Is called via the caldata within a flashloan.
     * - Repay debt token to the lending protocol.
     * - Withdraw collateral token.
     * - Swap poisition collateral token to debt token.
     * @param string The connector name that will be called are.
     * @param bytes Calldata needed to work with the connector `_datas and _targetNames must be with the same index`.
     * @param bytes Additional parameters for future use.
     * @param uint256 The amount needed to repay the flashloan.
     */
    function closePositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 _repayAmount
    ) external payable onlyCallback {
        execute(_targetNames[0], _datas[0]);
        execute(_targetNames[1], _datas[1]);

        uint256 returnedAmt = _swap(_targetNames[2], _datas[2]);

        DataTypes.Position memory position = getPosition(bytes32(_customDatas[0]));

        IERC20(position.debt).universalTransfer(ADDRESSES_PROVIDER.getFlashloanAggregator(), _repayAmount);
        IERC20(position.debt).universalTransfer(position.account, returnedAmt - _repayAmount);
    }

    /**
     * @dev Takes a loan, and call `callbackFunction` inside the loan.
     * @param address Flashloan token.
     * @param uint256 Flashloan amount.
     * @param uint256 The path chosen to take the loan See `FlashAggregator` contract.
     * @param bytes Calldata for the openPositionCallback.
     */
    function flashloan(address _token, uint256 _amount, uint256 route, bytes calldata _data) private {
        address[] memory _tokens = new address[](1);
        _tokens[0] = _token;

        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        IFlashAggregator(ADDRESSES_PROVIDER.getFlashloanAggregator()).flashLoan(
            _tokens,
            _amounts,
            route,
            _data,
            bytes("")
        );
    }

    /**
     * @dev Returns an instance of the router class.
     * @return Returns current router contract.
     */
    function getRouter() private view returns (IRouter) {
        return IRouter(ADDRESSES_PROVIDER.getRouter());
    }

    /**
     * @dev Takes a loan, and call `callbackFunction` inside the loan.
     * @param address Tokens that was Flashloan.
     * @param uint256 Amounts that was Flashloan.
     * @param uint256 Loan repayment fee.
     * @param address Address from which the loan was initiated.
     * @param bytes Calldata for the openPositionCallback.
     */
    function executeOperation(
        address[] calldata /* tokens */,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external onlyAggregator returns (bool) {
        require(initiator == address(this), Errors.INITIATOR_NOT_ACCOUNT);

        bytes memory encodeParams = encodingParams(params, amounts[0] + premiums[0]);
        (bool success, bytes memory results) = address(this).call(encodeParams);
        if (!success) {
            revert(string(results));
        }

        return true;
    }

    /**
     * @dev Takes a loan, and call `callbackFunction` inside the loan.
     * @param bytes parameters for the open and close position callback.
     * @param uint256 Loan amount plus loan fee.
     * @return Merged parameters of the callback and the loan amount.
     */
    function encodingParams(bytes memory params, uint256 amount) internal pure returns (bytes memory encode) {
        (bytes4 selector, string[] memory _targetNames, bytes[] memory _datas, bytes[] memory _customDatas) = abi
            .decode(params, (bytes4, string[], bytes[], bytes[]));

        encode = abi.encodeWithSelector(selector, _targetNames, _datas, _customDatas, amount);
    }

    /**
     * @dev Internal function for the exchange, sends tokens to the current contract.
     * @param string Name of the connector.
     * @param bytes Execute calldata.
     * @return Returns the amount of tokens received.
     */
    function _swap(string memory _name, bytes memory _data) internal returns (uint256 value) {
        bytes memory response = execute(_name, _data);
        value = abi.decode(response, (uint256));
    }

    /**
     * @dev Internal function for the charge fee for the using protocol.
     * @param uint256 Position amount.
     * @param address Position token.
     * @return Returns result of the operation.
     */
    function chargeFee(uint256 _amount, address _token) internal returns (bool success) {
        uint256 feeAmount = getRouter().getFeeAmount(_amount);
        success = IERC20(_token).universalTransfer(ADDRESSES_PROVIDER.getTreasury(), feeAmount);
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
