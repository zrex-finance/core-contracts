// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IAaveFlashloan } from '../interfaces/connectors/IAaveFlashloan.sol';

import { ILendingPool } from '../interfaces/external/aave-v2/ILendingPool.sol';
import { IProtocolDataProvider } from '../interfaces/external/aave-v2/IProtocolDataProvider.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

contract AaveV2Flashloan is BaseFlashloan, IAaveFlashloan {
    /* ============ Constants ============ */

    /**
     * @dev Aave Lending Pool
     */
    ILendingPool internal constant aaveLending = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    IProtocolDataProvider public constant aaveProtocolDataProvider =
        IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    string public constant override name = 'AaveV2Flashloan';

    /* ============ External Functions ============ */

    /**
     * @dev Callback function for aave flashloan.
     * @param _assets list of asset addresses for flashloan.
     * @param _amounts list of amounts for the corresponding assets for flashloan.
     * @param _premiums list of premiums/fees for the corresponding addresses for flashloan.
     * @param _initiator initiator address for flashloan.
     * @param _data extra data passed.
     */
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external override verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(aaveLending), 'not aave sender');

        (address sender, bytes memory data) = abi.decode(_data, (address, bytes));

        address asset = _assets[0];
        uint256 amount = _amounts[0];
        uint256 fee = _premiums[0];

        uint256 initialBalance = getBalance(asset);

        safeApprove(asset, amount + fee, address(aaveLending));
        safeTransfer(asset, amount, sender);

        IFlashReceiver(sender).executeOperation(asset, amount, fee, sender, name, data);

        require(initialBalance + fee <= getBalance(asset), 'amount paid less');

        return true;
    }

    /**
     * @dev Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @param _token token addresses for flashloan.
     * @param _amount list of amounts for the corresponding assets.
     * @param _data extra data passed.
     */
    function flashLoan(address _token, uint256 _amount, bytes calldata _data) external override reentrancy {
        _flashLoan(_token, _amount, _data);
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Returns fee for the passed route in BPS.
     * @notice Returns fee for the passed route in BPS. 1 BPS == 0.01%.
     */
    function calculateFeeBPS() public view override returns (uint256 bps) {
        bps = aaveLending.FLASHLOAN_PREMIUM_TOTAL();
    }

    /* ============ Internal Functions ============ */

    /**
     * @param _token token address for flashloan.
     * @param _amount amount for the corresponding assets or
     * amount of ether to borrow as collateral for flashloan.
     * @param _data extra data passed.
     */
    function _flashLoan(address _token, uint256 _amount, bytes memory _data) internal {
        bytes memory data = abi.encode(msg.sender, _data);
        _dataHash = bytes32(keccak256(data));

        address[] memory tokens = new address[](1);
        tokens[0] = _token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        aaveLending.flashLoan(address(this), tokens, amounts, modes, address(0), data, 0);
    }

    /**
     * @param _token token address for flashloan.
     * @param _amount amount for the corresponding assets or
     * amount of ether to borrow as collateral for flashloan.
     */
    function getAvailability(address _token, uint256 _amount) external view override returns (bool) {
        (, , , , , , , , bool isActive, ) = aaveProtocolDataProvider.getReserveConfigurationData(_token);
        (address aTokenAddr, , ) = aaveProtocolDataProvider.getReserveTokensAddresses(_token);
        if (isActive == false || IERC20(_token).balanceOf(aTokenAddr) < _amount) {
            return false;
        }
        return true;
    }
}
