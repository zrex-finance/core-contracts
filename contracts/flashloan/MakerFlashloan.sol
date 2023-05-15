// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IMakerFlashloan } from '../interfaces/IMakerFlashloan.sol';

import { IERC3156FlashLender } from '../interfaces/external/maker/IERC3156FlashLender.sol';
import { IERC3156FlashBorrower } from '../interfaces/external/maker/IERC3156FlashBorrower.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

contract MakerFlashloan is IMakerFlashloan, BaseFlashloan {
    /* ============ Constants ============ */

    /**
     * @dev Maker Lending
     */
    IERC3156FlashLender internal constant makerLending =
        IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);

    address public constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    string public constant override name = 'MakerFlashloan';

    /* ============ External Functions ============ */

    /**
     * @dev Fallback function for makerdao flashloan.
     * @param _initiator initiator address for flashloan.
     * _amount DAI amount for flashloan.
     * _fee fee for the flashloan.
     * @param _data extra data passed(includes route info aswell).
     */
    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external override verifyDataHash(_data) returns (bytes32) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(makerLending), 'not maker sender');

        (address asset, uint256 amount, address sender, bytes memory data) = abi.decode(
            _data,
            (address, uint256, address, bytes)
        );

        uint256 fee = calculateFee(amount, calculateFeeBPS());
        uint256 initialBalance = getBalance(asset);

        safeApprove(asset, amount + fee, address(makerLending));
        safeTransfer(asset, amount, sender);

        IFlashReceiver(sender).executeOperation(asset, amount, fee, sender, name, data);

        require(initialBalance + fee <= getBalance(asset), 'amount paid less');

        return keccak256('ERC3156FlashBorrower.onFlashLoan');
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
        bps = (makerLending.toll()) / (10 ** 14);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Middle function for route 2.
     * @param _token token address for flashloan(DAI).
     * @param _amount DAI amount for flashloan.
     * @param _data extra data passed.
     */
    function _flashLoan(address _token, uint256 _amount, bytes memory _data) internal {
        bytes memory data = abi.encode(_token, _amount, msg.sender, _data);
        _dataHash = bytes32(keccak256(data));
        makerLending.flashLoan(IERC3156FlashBorrower(address(this)), _token, _amount, data);
    }

    function getAvailability(address _token, uint256 _amount) external view override returns (bool) {
        if (_token == DAI_TOKEN) {
            return _amount <= makerLending.maxFlashLoan(DAI_TOKEN);
        }
        return false;
    }
}
