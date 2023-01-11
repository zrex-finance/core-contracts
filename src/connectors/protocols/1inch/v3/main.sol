// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenInterface } from "../../../common/interfaces.sol";
import { Stores } from "../../../common/stores.sol";
import { OneInchInterace, OneInchData } from "./interface.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

abstract contract OneInchResolver is Helpers, Events {

    function checkOneInchSig(bytes memory callData) internal pure returns(bool isOk) {
        bytes memory _data = callData;
        bytes4 sig;
        assembly {
            sig := mload(add(_data, 32))
        }
        isOk = sig == oneInchSwapSig || sig == oneInchUnoswapSig;
    }

    function oneInchSwap(
        OneInchData memory oneInchData,
        uint ethAmt
    ) internal returns (uint buyAmt) {
        TokenInterface buyToken = oneInchData.buyToken;

        uint initalBal = getTokenBalance(buyToken);

        (bool success, ) = oneInchAddr.call{value: ethAmt}(oneInchData.callData);
        if (!success) revert("1Inch-swap-failed");

        uint finalBal = getTokenBalance(buyToken);

        buyAmt = finalBal - initalBal;
    }

}

abstract contract OneInchResolverHelpers is OneInchResolver {

    function _sell(
        OneInchData memory oneInchData
    ) internal returns (OneInchData memory) {
        TokenInterface _sellAddr = oneInchData.sellToken;

        uint ethAmt;
        if (address(_sellAddr) == ethAddr) {
            ethAmt = oneInchData._sellAmt;
        } else {
            approve(TokenInterface(_sellAddr), oneInchAddr, oneInchData._sellAmt);
        }

        require(checkOneInchSig(oneInchData.callData), "Not-swap-function");

        oneInchData._buyAmt = oneInchSwap(oneInchData, ethAmt);

        return oneInchData;
    }
}

abstract contract OneInch is OneInchResolverHelpers {
    function sell(
        address buyAddr,
        address sellAddr,
        uint sellAmt,
        uint unitAmt,
        bytes calldata callData
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        OneInchData memory oneInchData = OneInchData({
            buyToken: TokenInterface(buyAddr),
            sellToken: TokenInterface(sellAddr),
            unitAmt: unitAmt,
            callData: callData,
            _sellAmt: sellAmt,
            _buyAmt: 0
        });

        oneInchData = _sell(oneInchData);

        _eventName = "LogSell(address,address,uint256,uint256,uint256)";
        _eventParam = abi.encode(buyAddr, sellAddr, oneInchData._buyAmt, oneInchData._sellAmt, 0);
    }
}

contract ConnectV2OneInchV3 is OneInch {
    string public name = "1Inch-v1.2";
}
