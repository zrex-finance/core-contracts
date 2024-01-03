// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'src/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'src/lib/DataTypes.sol';

import { EthConverter } from 'src/mocks/EthConverter.sol';

import { VixConnector } from 'src/connectors/zkevm/Vix.sol';
import { CTokenInterface } from 'src/interfaces/external/compound-v2/CTokenInterfaces.sol';
import { ComptrollerInterface } from 'src/interfaces/external/compound-v2/ComptrollerInterface.sol';

import { Tokens } from '../../utils/tokens.sol';

interface AaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract LendingHelper is Tokens {
    VixConnector vixConnector;

    ComptrollerInterface internal constant troller = ComptrollerInterface(0x6EA32f626e3A5c41547235ebBdf861526e11f482);

    function setUp() public {
        string memory url = vm.rpcUrl('zkevm');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        vixConnector = new VixConnector();
    }

    function getCollateralAmt(address _token, address _recipient) public returns (uint256 collateralAmount) {
        collateralAmount = vixConnector.collateralBalanceOf(_token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public returns (uint256 borrowAmount) {
        borrowAmount = vixConnector.borrowBalanceOf(_token, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(vixConnector.payback.selector, _token, _amount);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(vixConnector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(vixConnector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(vixConnector.borrow.selector, _token, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(vixConnector).delegatecall(_data);
        require(success);
    }
}

contract VixLogic is LendingHelper, EthConverter {
    function test_Deposit() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdc'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        assertGt(getCollateralAmt(getToken('usdt'), address(this)), 0);
    }

    function test_Deposit_Entered() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        address[] memory toEnter = new address[](1);
        toEnter[0] = address(vixConnector._getCToken(getToken('usdt')));
        troller.enterMarkets(toEnter);

        execute(getDepositData(getToken('usdt'), depositAmount));

        assertGt(getCollateralAmt(getToken('usdt'), address(this)), 0);
    }

    function test_Deposit_Max() public {
        uint256 depositAmount = 2_00_000_000;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        assertGt(getCollateralAmt(getToken('usdt'), address(this)), 0);
    }

    function test_Deposit_InvalidToken() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        vm.expectRevert(abi.encodePacked('Unsupported token'));
        execute(getDepositData(address(msg.sender), depositAmount));
    }

    function test_borrow() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        assertEq(borrowAmount, getBorrowAmt(getToken('usdc'), address(this)));
    }

    function test_Payback() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));

        assertEq(0, getBorrowAmt(getToken('usdc'), address(this)));
    }

    function test_Payback_NotEnoughToken() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        vm.expectRevert(abi.encodePacked('not enough token'));
        execute(getPaybackData(borrowAmount + 1000, getToken('usdc')));
    }

    function test_Payback_Max() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(type(uint256).max, getToken('usdc')));

        assertEq(0, getCollateralAmt(getToken('usdc'), address(this)));
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));
        execute(getWithdrawData(depositAmount, getToken('usdt')));

        assertEq(0, getCollateralAmt(getToken('usdt'), address(this)));
    }

    function test_Withdraw_Max() public {
        uint256 depositAmount = 1000 ether;

        deal(getToken('usdt'), address(this), depositAmount);

        execute(getDepositData(getToken('usdt'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));
        execute(getWithdrawData(type(uint256).max, getToken('usdt')));

        assertEq(0, getCollateralAmt(getToken('usdt'), address(this)));
    }

    function test_GetCToken() public {
        address[] memory _tokens = new address[](4);
        _tokens[0] = address(0);
        _tokens[1] = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
        _tokens[2] = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d;
        _tokens[3] = 0xa2036f0538221a77A3937F1379699f44945018d0;

        for (uint i = 0; i < _tokens.length; i++) {
            CTokenInterface token = vixConnector._getCToken(_tokens[i]);

            // for eth
            if (_tokens[i] != address(0)) {
                assertEq(token.underlying(), _tokens[i]);
            }
        }
    }
}
