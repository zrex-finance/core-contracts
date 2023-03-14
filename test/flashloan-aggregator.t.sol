// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

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
