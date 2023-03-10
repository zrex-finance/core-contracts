// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFlashLoan {
    function flashLoan(
        address[] memory tokens_,
        uint256[] memory amts_,
        uint256 route,
        bytes calldata data_,
        bytes calldata _customData
    ) external;
}

interface IImplimentation {
    function execute(address[] memory _targets, bytes[] memory _datas, address _origin) external;
}
