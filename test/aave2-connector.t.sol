// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SharedStructs } from "../src/lib/SharedStructs.sol";

import { HelperContract } from "./deployer.sol";

import { EthConverter } from "../src/utils/EthConverter.sol";

import { Connectors } from "../src/connectors/Connectors.sol";
import { AaveV2Connector } from "../src/connectors/AaveV2.sol";
import { IAave, IAaveLendingPoolProvider, IAaveDataProvider } from "../src/connectors/interfaces/AaveV2.sol";

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

    AaveV2Connector aaveV2Connector;

    IAaveLendingPoolProvider internal constant aaveProvider =
        IAaveLendingPoolProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IAaveDataProvider internal constant aaveDataProvider =
        IAaveDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    function setUp() public {
        string memory url = vm.rpcUrl("mainnet");
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        aaveV2Connector = new AaveV2Connector();
    }

    function getCollateralAmt(address _token, address _recipient) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveV2Connector.getCollateralBalance(_token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveV2Connector.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.payback.selector, _token, _amount, RATE_TYPE);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount, uint256 _rate) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.borrow.selector, _token, _rate, _amount);
    }

    function getSwapBorrowRateModeData(address _token, uint256 rateMode) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.swapBorrowRateMode.selector, _token, rateMode);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(aaveV2Connector).delegatecall(_data);
        require(success);
    }
}

contract AaveV2 is LendingHelper, EthConverter {
    uint256 public RAY = 1e27;
    uint256 public SECONDS_OF_THE_YEAR = 365 days;

    function test_Deposit() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);
        assertEq(depositAmount, getCollateralAmt(daiC, address(this)));
    }

    function test_DepositMax() public {
        uint256 depositAmount = 1000 ether;
        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(this), depositAmount);

        execute(getDepositData(daiC, type(uint256).max));
        assertEq(depositAmount, getCollateralAmt(daiC, address(this)));
    }

    function test_Borrow() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        assertEq(borrowAmount, getBorrowAmt(wethC, address(this)));
    }

    function test_SwapBorrowRate() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        swapBorrowRateMode(wethC, 2);

        assertEq(borrowAmount, aaveV2Connector.getPaybackBalance(wethC, 1, address(this)));
        assertEq(0, aaveV2Connector.getPaybackBalance(wethC, 2, address(this)));
    }

    function test_Payback() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        paybackWeth(borrowAmount);

        assertEq(0, getBorrowAmt(wethC, address(this)));
        assertEq(0, ERC20(wethC).balanceOf(address(this)));
    }

    function test_PaybackMax() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        paybackWeth(type(uint256).max);

        assertEq(0, getBorrowAmt(wethC, address(this)));
        assertEq(0, ERC20(wethC).balanceOf(address(this)));
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        paybackWeth(borrowAmount);
        withdraw(depositAmount);

        assertEq(0, getCollateralAmt(daiC, address(this)));
    }

    function test_EnableCollateral_NotAllowed() public {
        address[] memory _tokens = new address[](0);

        vm.expectRevert(abi.encodePacked("tokens not allowed"));
        execute(abi.encodeWithSelector(aaveV2Connector.enableCollateral.selector, _tokens));
    }

    function test_EnableCollateral() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        IAave aave = IAave(aaveProvider.getLendingPool());

        aave.setUserUseReserveAsCollateral(daiC, false);
        (, , , , , , , , bool isCol1) = aaveDataProvider.getUserReserveData(daiC, address(this));
        assertTrue(!isCol1);

        address[] memory _tokens = new address[](1);
        _tokens[0] = daiC;

        execute(abi.encodeWithSelector(aaveV2Connector.enableCollateral.selector, _tokens));

        (, , , , , , , , bool isCol2) = aaveDataProvider.getUserReserveData(daiC, address(this));
        assertTrue(isCol2);
    }

    function depositDai(uint256 _amount) public {
        vm.prank(daiWhale);
        ERC20(daiC).transfer(address(this), _amount);

        execute(getDepositData(daiC, _amount));
    }

    function borrowWeth(uint256 _amount, uint256 _rate) public {
        execute(getBorrowData(wethC, _amount, _rate));
    }

    function paybackWeth(uint256 _amount) public {
        execute(getPaybackData(_amount, wethC));
    }

    function withdraw(uint256 _amount) public {
        execute(getWithdrawData(_amount, daiC));
    }

    function swapBorrowRateMode(address _token, uint256 _rate) public {
        execute(getSwapBorrowRateModeData(_token, _rate));
    }
}
