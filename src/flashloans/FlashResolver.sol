// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC3156FlashLender } from "./interfaces/FlashAggregator.sol";
import { IAaveProtocolDataProvider, FlashloanAggregatorInterface } from "./interfaces/FlashResolver.sol";

contract FlashResolver {
    IERC3156FlashLender internal constant makerLending =
        IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);

    IAaveProtocolDataProvider public constant aaveProtocolDataProvider =
        IAaveProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    address public constant balancerLendingAddr = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant daiToken = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    FlashloanAggregatorInterface internal flashloanAggregator;

    constructor(address _flashloanAggregatorAddr) {
        flashloanAggregator = FlashloanAggregatorInterface(_flashloanAggregatorAddr);
    }

    function getRoutesInfo() public view returns (uint16[] memory routes_, uint256[] memory fees_) {
        routes_ = flashloanAggregator.getRoutes();
        fees_ = new uint256[](routes_.length);
        for (uint256 i = 0; i < routes_.length; i++) {
            fees_[i] = flashloanAggregator.calculateFeeBPS(routes_[i]);
        }
    }

    function getBestRoutes(
        address[] memory _tokens,
        uint256[] memory _amounts
    ) public view returns (uint16[] memory, uint256) {
        require(_tokens.length == _amounts.length, "array-lengths-not-same");

        validateTokens(_tokens);

        uint16[] memory bRoutes_;
        uint256 feeBPS_;
        uint16[] memory routes_ = flashloanAggregator.getRoutes();
        uint16[] memory routesWithAvailability_ = getRoutesWithAvailability(routes_, _tokens, _amounts);
        uint16 j = 0;
        bRoutes_ = new uint16[](routes_.length);
        feeBPS_ = type(uint256).max;
        for (uint256 i = 0; i < routesWithAvailability_.length; i++) {
            if (routesWithAvailability_[i] != 0) {
                uint256 routeFeeBPS_ = flashloanAggregator.calculateFeeBPS(routesWithAvailability_[i]);

                if (feeBPS_ > routeFeeBPS_) {
                    feeBPS_ = routeFeeBPS_;
                    bRoutes_[0] = routesWithAvailability_[i];
                    j = 1;
                } else if (feeBPS_ == routeFeeBPS_) {
                    bRoutes_[j] = routesWithAvailability_[i];
                    j++;
                }
            }
        }
        uint16[] memory bestRoutes_ = new uint16[](j);
        for (uint256 i = 0; i < j; i++) {
            bestRoutes_[i] = bRoutes_[i];
        }
        return (bestRoutes_, feeBPS_);
    }

    function getData(
        address[] memory _tokens,
        uint256[] memory _amounts
    )
        public
        view
        returns (uint16[] memory routes_, uint256[] memory fees_, uint16[] memory bestRoutes_, uint256 bestFee_)
    {
        (routes_, fees_) = getRoutesInfo();
        (bestRoutes_, bestFee_) = getBestRoutes(_tokens, _amounts);
        return (routes_, fees_, bestRoutes_, bestFee_);
    }

    function getAaveAvailability(address[] memory _tokens, uint256[] memory _amounts) internal view returns (bool) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token_ = IERC20(_tokens[i]);
            (, , , , , , , , bool isActive, ) = aaveProtocolDataProvider.getReserveConfigurationData(_tokens[i]);
            (address aTokenAddr, , ) = aaveProtocolDataProvider.getReserveTokensAddresses(_tokens[i]);
            if (isActive == false) {
                return false;
            }
            if (token_.balanceOf(aTokenAddr) < _amounts[i]) {
                return false;
            }
        }
        return true;
    }

    function getMakerAvailability(address[] memory _tokens, uint256[] memory _amounts) internal view returns (bool) {
        if (_tokens.length == 1 && _tokens[0] == daiToken) {
            uint256 loanAmt = makerLending.maxFlashLoan(daiToken);
            return _amounts[0] <= loanAmt;
        }
        return false;
    }

    function getBalancerAvailability(address[] memory _tokens, uint256[] memory _amounts) internal view returns (bool) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token_ = IERC20(_tokens[i]);
            if (token_.balanceOf(balancerLendingAddr) < _amounts[i]) {
                return false;
            }
        }
        return true;
    }

    function getRoutesWithAvailability(
        uint16[] memory _routes,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal view returns (uint16[] memory) {
        uint16[] memory routesWithAvailability_ = new uint16[](3);
        uint256 j = 0;
        for (uint256 i = 0; i < _routes.length; i++) {
            if (_routes[i] == 1) {
                if (getAaveAvailability(_tokens, _amounts)) {
                    routesWithAvailability_[j] = _routes[i];
                    j++;
                }
            } else if (_routes[i] == 2) {
                if (getMakerAvailability(_tokens, _amounts)) {
                    routesWithAvailability_[j] = _routes[i];
                    j++;
                }
            } else if (_routes[i] == 3) {
                if (getBalancerAvailability(_tokens, _amounts)) {
                    routesWithAvailability_[j] = _routes[i];
                    j++;
                }
            } else {
                require(false, "invalid-route");
            }
        }
        return routesWithAvailability_;
    }

    function validateTokens(address[] memory _tokens) internal pure {
        for (uint256 i = 0; i < _tokens.length - 1; i++) {
            require(_tokens[i] != _tokens[i + 1], "non-unique-tokens");
        }
    }
}
