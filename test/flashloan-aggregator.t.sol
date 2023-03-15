// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "../src/dependencies/openzeppelin/contracts/IERC20.sol";
import { Clones } from "../src/dependencies/openzeppelin/upgradeability/Clones.sol";

import { FlashAggregator } from "../src/flashloans/FlashAggregator.sol";
import { FlashResolver } from "../src/flashloans/FlashResolver.sol";

contract TestFlashAggregator is Test {
    FlashAggregator flashAggregator;
    FlashResolver flashResolver;

    address daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    uint256 public amount = 1000 ether;
    address public token = daiC;

    function test_flashloan() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;

        (, , uint16[] memory bestRoutes_, ) = flashResolver.getData(_tokens, _amounts);

        for (uint i = 0; i < bestRoutes_.length; i++) {
            flashAggregator.flashLoan(_tokens, _amounts, bestRoutes_[i], bytes(""), bytes(""));
        }
    }

    function test_executeOperation() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 900000000000000000;

        bytes memory data_ = abi.encode(1, address(this), bytes("Hello"));

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

        bytes memory data_ = abi.encode(1, address(this), bytes("Hello"));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked("not same sender"));
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

        bytes memory data_ = abi.encode(1, address(this), bytes("Hello"));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked("not aave sender"));
        flashAggregator.executeOperation(_tokens, _amounts, _premiums, address(flashAggregator), data_);
    }

    function test_onFlashLoan() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(2, _tokens, _amounts, address(this), bytes(""));

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

        bytes memory data_ = abi.encode(2, _tokens, _amounts, address(this), bytes(""));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked("not same sender"));
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

        bytes memory data_ = abi.encode(2, _tokens, _amounts, address(this), bytes(""));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked("not maker sender"));
        flashAggregator.onFlashLoan(address(flashAggregator), address(0), type(uint256).max, type(uint256).max, data_);
    }

    function test_receiveFlashLoan() public {
        address[] memory _tokens = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _premiums = new uint256[](1);
        _tokens[0] = token;
        _amounts[0] = amount;
        _premiums[0] = 0;

        bytes memory data_ = abi.encode(3, _tokens, _amounts, address(this), bytes(""));

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

        bytes memory data_ = abi.encode(3, _tokens, _amounts, address(this), bytes(""));

        vm.store(address(flashAggregator), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(flashAggregator), bytes32(uint256(1)), bytes32(keccak256(data_)));

        vm.prank(0xb527a981e1d415AF696936B3174f2d7aC8D11369);
        IERC20(token).transfer(address(flashAggregator), amount);

        vm.expectRevert(abi.encodePacked("not balancer sender"));
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
        assertEq(tokens[0], token);
        assertEq(amounts[0], amount);

        assertEq(amount, IERC20(tokens[0]).balanceOf(address(this)));

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
        string memory url = vm.rpcUrl("mainnet");
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        flashAggregator = new FlashAggregator();
        flashResolver = new FlashResolver(address(flashAggregator));
    }
}
