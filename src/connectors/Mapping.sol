// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { UniversalERC20 } from "../lib/UniversalERC20.sol";

import { ICToken } from "./interfaces/Mapping.sol";

contract Mapping is Ownable {
    using UniversalERC20 for IERC20;

    event LogCTokenUpdated(address indexed token, address indexed ctoken);

    // token -> ctoken
    mapping(address => address) public cTokenMapping;

    string public constant name = "Compound Mapping";

    constructor(address[] memory _tokens, address[] memory _ctokens) {
        _updateCtokenMapping(_tokens, _ctokens);
    }

    function _updateCtokenMapping(address[] memory _tokens, address[] memory _ctokens) internal onlyOwner {
        uint256 _length = _ctokens.length;
        require(_length == _tokens.length, "not same length");

        for (uint i = 0; i < _length; i++) {
            address _token = _tokens[i];
            address _ctoken = _ctokens[i];

            require(cTokenMapping[_token] == address(0), "mapping added already");
            require(_token != address(0), "_tokens address not vaild");
            require(_ctoken != address(0), "_ctokens address not vaild");

            ICToken _ctokenC = ICToken(_ctoken);

            require(_ctokenC.isCToken(), "not a cToken");
            if (!IERC20(_token).isETH()) {
                require(_ctokenC.underlying() == _token, "mapping mismatch");
            }

            cTokenMapping[_token] = _ctoken;
            emit LogCTokenUpdated(_token, _ctoken);
        }
    }

    function addCtokenMapping(address[] memory _tokens, address[] memory _ctokens) external {
        _updateCtokenMapping(_tokens, _ctokens);
    }

    function getMapping(address _token) external view returns (address, address) {
        address ctoken = cTokenMapping[_token];
        return (_token, ctoken);
    }
}
