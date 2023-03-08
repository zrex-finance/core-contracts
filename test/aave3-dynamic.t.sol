// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SharedStructs } from "../src/lib/SharedStructs.sol";

import { HelperContract } from "./deployer.sol";

import { EthConverter } from "../src/utils/EthConverter.sol";

import { Connectors } from "../src/connectors/Connectors.sol";
import { AaveV3Connector } from "../src/connectors/AaveV3.sol";
import { IAave, IAavePoolProvider, IAaveDataProvider } from "../src/connectors/interfaces/AaveV3.sol";

contract Tokens {
    address usdcC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address ethC = 0x0000000000000000000000000000000000000000;
    address ethC2 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
}

interface AaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract LendingHelper is HelperContract, Tokens {

    uint256 RATE_TYPE = 2;
    string NAME = "AaveV3";

    AaveV3Connector aaveV3Connector;

    AaveOracle public aaveOracle = AaveOracle(0x54586bE62E3c3580375aE3723C145253060Ca0C2);
    IAavePoolProvider internal constant aaveProvider = IAavePoolProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IAaveDataProvider internal constant aaveDataProvider = IAaveDataProvider(0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3);

    function setUp() public {
        string memory url = vm.rpcUrl("mainnet");
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        aaveV3Connector = new AaveV3Connector();
    }

    function getPaybackData(uint256 _amount, address _token) public view returns(bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.payback.selector, _token, _amount, RATE_TYPE);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns(bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns(bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns(bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.borrow.selector, _token, RATE_TYPE, _amount);
    }

    function execute(bytes memory _data) public {
      (bool success,) = address(aaveV3Connector).delegatecall(_data);
      require(success);
    }
}

contract AaveV3 is LendingHelper, EthConverter {

    uint256 public SECONDS_OF_THE_YEAR = 365 days;
    uint256 public RAY = 1e27;

    function testAaveFullCase() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(this), depositAmount);

        execute(getDepositData(daiC, depositAmount));

        uint256 wethPrice = aaveOracle.getAssetPrice(wethC);

        (uint256 daiDecimals, uint256 ltv,,,,,,,,) = aaveDataProvider.getReserveConfigurationData(daiC);

        uint256 wethDecimals = ERC20(wethC).decimals();
        uint256 daiPrice = aaveOracle.getAssetPrice(daiC);

        uint256 totalDai = daiPrice * depositAmount / (10 ** daiDecimals);
        uint256 maxBorrowAmountInBase = (totalDai / 100) * ((ltv / 100));
        uint256 borrowAmount = (maxBorrowAmountInBase * (10 ** wethDecimals)) / wethPrice;

        execute(getBorrowData(wethC, borrowAmount));

        paybackAndWithdraw(borrowAmount, depositAmount);
    }

    function paybackAndWithdraw(uint256 borrowAmount, uint256 depositAmount) public {
      uint256 timestamp = block.timestamp + 1 days;
      (,,,,,,uint256 variableBorrowRate,,,,,uint40 lastUpdate) = aaveDataProvider.getReserveData(wethC);

      uint256 timePassed = timestamp - lastUpdate;
      uint256 ratePerTime = (variableBorrowRate / SECONDS_OF_THE_YEAR) * timePassed;
      uint256 borrowFeeAmount = (borrowAmount * RAY) / ratePerTime;
      uint256 paybackAmount = borrowFeeAmount + borrowAmount;

      convertEthToWeth(wethC, borrowFeeAmount);

      execute(getPaybackData(paybackAmount, wethC));
      execute(getWithdrawData(depositAmount, daiC));
    }
}