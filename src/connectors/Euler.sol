// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniversalERC20 } from "../libraries/tokens/UniversalERC20.sol";

import { IEulerEToken, IEulerDToken, IEulerMarkets } from "./interfaces/Euler.sol";

contract EulerConnector {
    using UniversalERC20 for IERC20;

    address internal constant EULER_MAINNET = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    IEulerMarkets internal constant markets = IEulerMarkets(0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3);

    string public constant name = "Euler";

    function deposit(uint256 subAccount, address token, bool enableCollateral, uint256 amount) external payable {
        IERC20 tokenC = IERC20(token);

        amount = amount == type(uint).max ? tokenC.balanceOf(address(this)) : amount;

        tokenC.universalApprove(EULER_MAINNET, amount);

        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(token));
        eToken.deposit(subAccount, amount);

        if (enableCollateral) {
            markets.enterMarket(subAccount, token);
        }
    }

    function borrowBalanceOf(address token, address _recipient, uint256 _subAccount) public view returns (uint256) {
        IEulerDToken borrowedDToken = IEulerDToken(markets.underlyingToDToken(token));

        address subAccount = getSubAccount(_recipient, _subAccount);

        return borrowedDToken.balanceOf(subAccount);
    }

    function collateralBalanceOf(address token, address _recipient, uint256 _subAccount) public view returns (uint256) {
        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(token));

        address subAccount = getSubAccount(_recipient, _subAccount);

        return eToken.balanceOfUnderlying(subAccount);
    }

    function withdraw(uint256 subAccount, address token, uint256 amount) external payable {
        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(token));

        address _subAccount = getSubAccount(address(this), subAccount);

        amount = amount == type(uint).max ? eToken.balanceOfUnderlying(_subAccount) : amount;

        eToken.withdraw(subAccount, amount);
    }

    function borrow(uint256 subAccount, address token, uint256 amount) external payable {
        IEulerDToken borrowedDToken = IEulerDToken(markets.underlyingToDToken(token));
        borrowedDToken.borrow(subAccount, amount);
    }

    function repay(uint256 subAccount, address token, uint256 amount) external payable {
        IEulerDToken borrowedDToken = IEulerDToken(markets.underlyingToDToken(token));

        address _subAccount = getSubAccount(address(this), subAccount);

        amount = amount == type(uint).max ? borrowedDToken.balanceOf(_subAccount) : amount;

        IERC20(token).universalApprove(EULER_MAINNET, amount);
        borrowedDToken.repay(subAccount, amount);
    }

    function enterMarket(uint256 subAccountId, address[] memory tokens) external payable {
        uint256 _length = tokens.length;
        require(_length > 0, "0-markets-not-allowed");

        for (uint256 i = 0; i < _length; i++) {
            markets.enterMarket(subAccountId, tokens[i]);
        }
    }

    function getSubAccount(address primary, uint256 subAccountId) public pure returns (address) {
        require(subAccountId < 256, "sub-account-id-too-big");
        return address(uint160(primary) ^ uint160(subAccountId));
    }
}
