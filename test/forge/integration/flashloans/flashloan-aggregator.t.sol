// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { IERC20 } from 'contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import { Clones } from 'contracts/dependencies/openzeppelin/upgradeability/Clones.sol';

import { IFlashAggregator } from 'contracts/interfaces/IFlashAggregator.sol';

import { FlashAggregator } from 'contracts/FlashAggregator.sol';
import { FlashResolver } from 'contracts/FlashResolver.sol';

contract FakeAggregator {
    function getRoutes() public pure returns (uint16[] memory routes) {
        routes = new uint16[](4);
        routes[0] = 1;
        routes[1] = 2;
        routes[2] = 3;
        routes[3] = 4;
    }

    function calculateFeeBPS(uint256) public pure returns (uint256 BPS) {
        BPS = 1;
    }
}

contract FakeAggregator2 {
    function getRoutes() public pure returns (uint16[] memory routes) {
        routes = new uint16[](3);
        routes[0] = 1;
        routes[1] = 2;
        routes[2] = 3;
    }

    function calculateFeeBPS(uint256) public pure returns (uint256 BPS) {
        BPS = 9;
    }
}

contract TestFlashAggregator is Test {
    FlashAggregator flashAggregator;
    FlashResolver flashResolver;

    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    uint256 public amount = 1000 ether;
    address public token = daiC;

    function test_flashloan_getData() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;

        (uint16[] memory routes, uint256[] memory fees, uint16[] memory bestRoutes, uint256 bestFee) = flashResolver
            .getData(_tokens, _amounts);

        flashAggregator.flashLoan(
            _tokens,
            _amounts,
            bestRoutes[0],
            bytes(''),
            abi.encodePacked(bestFee, bestRoutes, fees, routes)
        );
    }

    function test_flashloan_getDataFake() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;

        FakeAggregator2 fakeAggregator2 = new FakeAggregator2();
        FlashResolver flashResolver2 = new FlashResolver(IFlashAggregator(address(fakeAggregator2)));

        (uint16[] memory routes, uint256[] memory fees, uint16[] memory bestRoutes, uint256 bestFee) = flashResolver2
            .getData(_tokens, _amounts);

        flashAggregator.flashLoan(
            _tokens,
            _amounts,
            bestRoutes[0],
            bytes(''),
            abi.encodePacked(bestFee, bestRoutes, fees, routes)
        );
    }

    function test_flashloan_getDataInvalid() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;

        FakeAggregator fakeAggregator = new FakeAggregator();
        FlashResolver flashResolver2 = new FlashResolver(IFlashAggregator(address(fakeAggregator)));

        vm.expectRevert(abi.encodePacked('invalid-route'));
        flashResolver2.getData(_tokens, _amounts);
    }

    function test_flashloan_aave() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;

        flashAggregator.flashLoan(_tokens, _amounts, 1, bytes(''), bytes(''));
    }

    function test_flashloan_MakerTryCatch() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;

        // maker disable flashloan
        try flashAggregator.flashLoan(_tokens, _amounts, 2, bytes(''), bytes('')) {} catch {}
    }

    function test_flashloan_balancer() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _amounts[0] = 1 ether;

        flashAggregator.flashLoan(_tokens, _amounts, 3, bytes(''), bytes(''));
    }

    function test_flashloan_aaveIsActiveFalse() public view {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = 0x77777FeDdddFfC19Ff86DB637967013e6C6A116C;
        _amounts[0] = type(uint256).max;

        flashResolver.getData(_tokens, _amounts);
    }

    function test_flashloan_balancerMax() public view {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _amounts[0] = type(uint256).max;

        flashResolver.getData(_tokens, _amounts);
    }

    function test_flashloan_AaveMax() public view {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = type(uint256).max;

        flashResolver.getData(_tokens, _amounts);
    }

    function test_flashloan_balancerInvalidToken() public {
        address[] memory _tokens = new address[](2);
        uint256[] memory _amounts = new uint256[](2);
        _tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _tokens[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _amounts[0] = type(uint256).max;
        _amounts[1] = type(uint256).max;

        vm.expectRevert(abi.encodePacked('non-unique-tokens'));
        flashResolver.getData(_tokens, _amounts);
    }

    function test_flashloan_NonUniqueTokens() public {
        address[] memory _tokens = new address[](2);
        uint256[] memory _amounts = new uint256[](2);
        _tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _tokens[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _amounts[0] = 1 ether;
        _amounts[1] = 1 ether;

        vm.expectRevert(abi.encodePacked('non unique tokens'));
        flashAggregator.flashLoan(_tokens, _amounts, 3, bytes(''), bytes(''));
    }

    function test_flashloan_RouteDoesNotExist() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _amounts[0] = 1 ether;

        vm.expectRevert(abi.encodePacked('route-does-not-exist'));
        flashAggregator.flashLoan(_tokens, _amounts, 4, bytes(''), bytes(''));
    }

    function test_CalculateFeeBPS_InvalidRoute() public {
        vm.expectRevert(abi.encodePacked('invalid route'));
        flashAggregator.calculateFeeBPS(4);
    }

    function test_executeOperation() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 900000000000000000;

        bytes memory data_ = abi.encode(1, address(this), bytes('Hello'));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.prank(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        flashAggregator.executeOperation(_tokens, _amounts, _premiums, address(flashAggregator), data_);
    }

    function test_executeOperation_NotSameSender() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 900000000000000000;

        bytes memory data_ = abi.encode(1, address(this), bytes('Hello'));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked('not same sender'));
        vm.prank(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        flashAggregator.executeOperation(_tokens, _amounts, _premiums, msg.sender, data_);
    }

    function test_executeOperation_NotAaveSender() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 900000000000000000;

        bytes memory data_ = abi.encode(1, address(this), bytes('Hello'));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked('not aave sender'));
        flashAggregator.executeOperation(_tokens, _amounts, _premiums, address(flashAggregator), data_);
    }

    function test_onFlashLoan() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(2, _tokens, _amounts, address(this), bytes(''));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.prank(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
        flashAggregator.onFlashLoan(address(flashAggregator), address(0), type(uint256).max, type(uint256).max, data_);
    }

    function test_onFlashLoan_NotSameSender() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(2, _tokens, _amounts, address(this), bytes(''));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked('not same sender'));
        vm.prank(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
        flashAggregator.onFlashLoan(address(msg.sender), address(0), type(uint256).max, type(uint256).max, data_);
    }

    function test_onFlashLoan_NotMakerSender() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(2, _tokens, _amounts, address(this), bytes(''));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked('not maker sender'));
        flashAggregator.onFlashLoan(address(flashAggregator), address(0), type(uint256).max, type(uint256).max, data_);
    }

    function test_receiveFlashLoan() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(3, _tokens, _amounts, address(this), bytes(''));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.prank(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        flashAggregator.receiveFlashLoan(_tokens, _amounts, _premiums, data_);
    }

    function test_receiveFlashLoan_NotBalancerSender() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(3, _tokens, _amounts, address(this), bytes(''));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked('not balancer sender'));
        flashAggregator.receiveFlashLoan(_tokens, _amounts, _premiums, data_);
    }

    function executeOperation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata /* params */
    ) external returns (bool) {
        assertEq(initiator, address(this));

        assertEq(amounts[0], IERC20(tokens[0]).balanceOf(address(this)));

        if (premiums[0] > 0) {
            vm.prank(daiWhale);
            IERC20(daiC).transfer(address(this), premiums[0]);

            IERC20(tokens[0]).transfer(address(flashAggregator), amounts[0] + premiums[0]);
        } else {
            IERC20(tokens[0]).transfer(address(flashAggregator), amounts[0]);
        }

        return true;
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        flashAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(IFlashAggregator(address(flashAggregator)));
    }
}
