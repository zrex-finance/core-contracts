// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFlashReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata _data
    ) external returns (bool);
}

interface IAaveLending {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint256);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function flashLoan(
        IFlashReceiver receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    function toll() external view returns (uint256);
}

interface IProtocolFeesCollector {
    function getFlashLoanFeePercentage() external view returns (uint256);
}

interface IBalancerLending {
    function flashLoan(
        IFlashReceiver recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);
}
