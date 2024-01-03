// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'src/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'src/lib/DataTypes.sol';

import { EthConverter } from 'src/mocks/EthConverter.sol';

import { VenusConnector } from 'src/connectors/bsc/Venus.sol';
import { CTokenInterface } from 'src/interfaces/external/compound-v2/CTokenInterfaces.sol';
import { ComptrollerInterface } from 'src/interfaces/external/compound-v2/ComptrollerInterface.sol';

import { Tokens } from '../../utils/tokens.sol';

contract LendingHelper is Tokens {
    VenusConnector venusConnector;

    ComptrollerInterface internal constant troller = ComptrollerInterface(0xfD36E2c2a6789Db23113685031d7F16329158384);

    function setUp() public {
        string memory url = vm.rpcUrl('bsc');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        venusConnector = new VenusConnector();
    }

    function getCollateralAmt(address _token, address _recipient) public returns (uint256 collateralAmount) {
        collateralAmount = venusConnector.collateralBalanceOf(_token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public returns (uint256 borrowAmount) {
        borrowAmount = venusConnector.borrowBalanceOf(_token, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.payback.selector, _token, _amount);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.borrow.selector, _token, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(venusConnector).delegatecall(_data);
        require(success);
    }
}

contract VenusLogic is LendingHelper, EthConverter {
    function test_Deposit() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_Entered() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        address[] memory toEnter = new address[](1);
        toEnter[0] = address(venusConnector._getCToken(getToken('dai')));
        troller.enterMarkets(toEnter);

        execute(getDepositData(getToken('dai'), depositAmount));

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), type(uint256).max));

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_InvalidToken() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        vm.expectRevert(abi.encodePacked('Unsupported token'));
        execute(getDepositData(address(msg.sender), depositAmount));
    }

    function test_borrow() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        assertEq(borrowAmount, getBorrowAmt(getToken('usdc'), address(this)));
    }

    function test_Payback() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));

        assertEq(0, getBorrowAmt(getToken('usdc'), address(this)));
    }

    function test_Payback_NotEnoughToken() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        vm.expectRevert(abi.encodePacked('not enough token'));
        execute(getPaybackData(borrowAmount + 1000, getToken('usdc')));
    }

    function test_Payback_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(type(uint256).max, getToken('usdc')));

        assertEq(0, getCollateralAmt(getToken('usdc'), address(this)));
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));
        execute(getWithdrawData(depositAmount, getToken('dai')));

        assertEq(0, getCollateralAmt(getToken('dai'), address(this)));
    }

    function test_Withdraw_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));
        execute(getWithdrawData(type(uint256).max, getToken('dai')));

        assertEq(0, getCollateralAmt(getToken('dai'), address(this)));
    }

    function test_GetCToken() public {
        address[] memory _tokens = new address[](26);
        _tokens[0] = address(0);
        _tokens[1] = 0x47BEAd2563dCBf3bF2c9407fEa4dC236fAbA485A;
        _tokens[2] = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
        _tokens[3] = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        _tokens[4] = 0x55d398326f99059fF775485246999027B3197955;
        _tokens[5] = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        _tokens[6] = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
        _tokens[7] = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
        _tokens[8] = 0x4338665CBB7B2485A8855A139b75D5e34AB0DB94;
        _tokens[9] = 0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE;
        _tokens[10] = 0x8fF795a6F4D97E7887C79beA79aba5cc76444aDf;
        _tokens[11] = 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402;
        _tokens[12] = 0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD;
        _tokens[13] = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
        _tokens[14] = 0x0D8Ce2A99Bb6e3B7Db580eD848240e4a0F9aE153;
        _tokens[15] = 0x250632378E573c6Be1AC2f97Fcdf00515d0Aa91B;
        _tokens[16] = 0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47;
        _tokens[17] = 0xbA2aE424d960c26247Dd6c32edC70B295c744C43;
        _tokens[18] = 0xCC42724C6683B7E57334c4E856f4c9965ED682bD;
        _tokens[19] = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
        _tokens[20] = 0xfb6115445Bff7b52FeB98650C87f44907E58f802;
        _tokens[21] = 0x14016E85a25aeb13065688cAFB43044C2ef86784;
        _tokens[22] = 0x85EAC5Ac2F758618dFa09bDbe0cf174e7d574D5B;
        _tokens[23] = 0x3d4350cD54aeF9f9b2C29435e0fa809957B3F30a;
        _tokens[24] = 0x156ab3346823B651294766e23e6Cf87254d68962;
        _tokens[25] = 0xCE7de646e7208a4Ef112cb6ed5038FA6cC6b12e3;

        for (uint i = 0; i < _tokens.length; i++) {
            CTokenInterface token = venusConnector._getCToken(_tokens[i]);

            // for eth
            if (_tokens[i] != address(0)) {
                assertEq(token.underlying(), _tokens[i]);
            }
        }
    }
}
