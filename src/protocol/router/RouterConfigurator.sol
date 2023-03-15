// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IRouter } from "../../interfaces/IRouter.sol";
import { IAddressesProvider } from "../../interfaces/IAddressesProvider.sol";
import { Initializable } from "../../dependencies/openzeppelin/upgradeability/Initializable.sol";

/**
 * @title RouterConfigurator
 * @author FlashFlow
 * @dev Implements the configuration methods for the FlashFlow protocol
 */
contract RouterConfigurator is Initializable {
    IRouter internal _router;
    IAddressesProvider internal _addressesProvider;

    function initialize(IAddressesProvider provider) public initializer {
        _addressesProvider = provider;
        _router = IRouter(_addressesProvider.getRouter());
    }
}
