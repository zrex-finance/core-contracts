// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Connectors } from "../src/protocol/configuration/Connectors.sol";
import { Errors } from "../src/protocol/libraries/helpers/Errors.sol";

contract ConnectorImpl {
    string public constant name = "ConnectorImpl";
}

contract TestConnectors is Test {
    Connectors connectors;

    function test_addConnectors_InvalidLength() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTORS_LENGTH));
        connectors.addConnectors(_names, _connectors);
    }

    function test_addConnectors_InvalidAddress() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(0);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTOR_ADDRESS));
        connectors.addConnectors(_names, _connectors);
    }

    function test_addConnectors_AlreadyExist() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](2);
        _names[0] = connector.name();
        _names[1] = connector.name(); // same name

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);
        _connectors[1] = address(new ConnectorImpl());

        vm.expectRevert(abi.encodePacked(Errors.CONNECTOR_ALREADY_EXIST));
        connectors.addConnectors(_names, _connectors);
    }

    function test_addConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        connectors.addConnectors(_names, _connectors);

        (bool isOk, address _connector) = connectors.isConnector(_names[0]);
        assertTrue(isOk);
        assertEq(_connectors[0], _connector);
    }

    function test_updateConnectors_InvalidLength() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTORS_LENGTH));
        connectors.updateConnectors(_names, _connectors);
    }

    function test_updateConnectors_InvalidAddress() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        connectors.addConnectors(_names, _connectors);

        _connectors[0] = address(0);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTOR_ADDRESS));
        connectors.updateConnectors(_names, _connectors);
    }

    function test_updateConnectors_DoesntExist() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](2);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.CONNECTOR_DOES_NOT_EXIST));
        connectors.updateConnectors(_names, _connectors);
    }

    function test_updateConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        connectors.addConnectors(_names, _connectors);

        (bool isOk0, address _connector0) = connectors.isConnector(_names[0]);
        assertTrue(isOk0);
        assertEq(_connectors[0], _connector0);

        address newConnector = address(new ConnectorImpl());
        _connectors[0] = newConnector;

        connectors.updateConnectors(_names, _connectors);

        (bool isOk1, address _connector1) = connectors.isConnector(_names[0]);
        assertTrue(isOk1);
        assertEq(newConnector, _connector1);
    }

    function test_removeConnectors_DoesntExist() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](2);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.CONNECTOR_DOES_NOT_EXIST));
        connectors.removeConnectors(_names);
    }

    function test_removeConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.name();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        connectors.addConnectors(_names, _connectors);

        (bool isTrue, address _connector) = connectors.isConnector(_names[0]);
        assertTrue(isTrue);
        assertEq(_connectors[0], _connector);

        connectors.removeConnectors(_names);

        (bool isFalse, address _removeConnector) = connectors.isConnector(_names[0]);
        assertFalse(isFalse);
        assertEq(address(0), _removeConnector);
    }

    receive() external payable {}

    function setUp() public {
        connectors = new Connectors();
    }
}
