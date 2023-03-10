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

import "forge-std/Test.sol";

contract Account is Initializable, Test {
    using UniversalERC20 for IERC20;

    address private _owner;
    IAddressesProvider public ADDRESSES_PROVIDER;

    receive() external payable {}

    modifier onlyOwner() {
        require(_owner == msg.sender, Errors.CALLER_NOT_ACCOUNT_OWNER);
        _;
    }

    modifier onlyCallback() {
        require(msg.sender == address(this), Errors.CALLER_NOT_RECEIVER);
        _;
    }

    modifier onlyAggregator() {
        require(msg.sender == ADDRESSES_PROVIDER.getFlashloanAggregator(), Errors.CALLER_NOT_FLASH_AGGREGATOR);
        _;
    }

    function initialize(address _user, IAddressesProvider _provider) public initializer {
        require(address(_provider) != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
        ADDRESSES_PROVIDER = _provider;
        _owner = _user;
    }

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

    function getPosition(bytes32 _key) private returns (DataTypes.Position memory) {
        DataTypes.Position memory position = getRouter().positions(_key);
        require(position.account == _owner, Errors.CALLER_NOT_POSITION_OWNER);
        return position;
    }

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

    function getRouter() private view returns (IRouter) {
        return IRouter(ADDRESSES_PROVIDER.getRouter());
    }

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

    function encodingParams(bytes memory params, uint256 amount) internal pure returns (bytes memory encode) {
        (bytes4 selector, string[] memory _targetNames, bytes[] memory _datas, bytes[] memory _customDatas) = abi
            .decode(params, (bytes4, string[], bytes[], bytes[]));

        encode = abi.encodeWithSelector(selector, _targetNames, _datas, _customDatas, amount);
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

    function _swap(string memory _name, bytes memory _data) internal returns (uint256 value) {
        bytes memory response = execute(_name, _data);
        value = abi.decode(response, (uint256));
    }

    function chargeFee(uint256 _amount, address _token) internal returns (bool success) {
        uint256 feeAmount = getRouter().getFeeAmount(_amount);
        success = IERC20(_token).universalTransfer(ADDRESSES_PROVIDER.getTreasury(), feeAmount);
    }
}
