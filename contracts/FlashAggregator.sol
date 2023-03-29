// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from './dependencies/openzeppelin/contracts/IERC20.sol';

import { IFlashReceiver } from './interfaces/IFlashReceiver.sol';
import { IFlashAggregator } from './interfaces/IFlashAggregator.sol';

import { IVault } from './interfaces/external/balancer/IVault.sol';
import { ILendingPool } from './interfaces/external/aave-v2/ILendingPool.sol';
import { IERC3156FlashLender } from './interfaces/external/maker/IERC3156FlashLender.sol';
import { IERC3156FlashBorrower } from './interfaces/external/maker/IERC3156FlashBorrower.sol';
import { IFlashLoanRecipient } from './interfaces/external/balancer/IFlashLoanRecipient.sol';

import { UniversalERC20 } from './lib/UniversalERC20.sol';

contract FlashAggregator is IFlashAggregator {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Aave Lending Pool
     */
    ILendingPool internal constant aaveLending = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    /**
     * @dev Maker Lending
     */
    IERC3156FlashLender internal constant makerLending =
        IERC3156FlashLender(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);

    /**
     * @dev Balancer Lending
     */
    IVault internal constant balancerLending = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint16 internal constant ROUTE_AAVE = 1;
    uint16 internal constant ROUTE_MAKER = 2;
    uint16 internal constant ROUTE_BALANCER = 3;

    /* ============ State Variables ============ */

    // Has state 1 on the enter flashlaon and state 2 on the callback
    uint256 internal _status;

    // The hash of the date that is sent to the flashloan as an additional calldata
    bytes32 internal _dataHash;

    /* ============ Events ============ */

    event LogFlashloan(address indexed account, uint256 indexed route, address[] tokens, uint256[] amounts);

    /* ============ Modifiers ============ */

    /**
     * @dev  better checking by double encoding the data.
     * @notice better checking by double encoding the data.
     * @param data_ data passed.
     */
    modifier verifyDataHash(bytes memory data_) {
        bytes32 dataHash_ = keccak256(data_);
        require(dataHash_ == _dataHash && dataHash_ != bytes32(0), 'invalid-data-hash');
        require(_status == 2, 'already-entered');
        _dataHash = bytes32(0);
        _;
        _status = 1;
    }

    /**
     * @dev reentrancy gaurd.
     * @notice reentrancy gaurd.
     */
    modifier reentrancy() {
        require(_status == 1, 'already-entered');
        _status = 2;
        _;
        require(_status == 1, 'already-entered');
    }

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @notice Sets the status to the default value
     */
    constructor() {
        require(_status == 0, 'cannot call again');
        _status = 1;
    }

    /* ============ External Functions ============ */

    /**
     * @dev Callback function for aave flashloan.
     * @param _assets list of asset addresses for flashloan.
     * @param _amounts list of amounts for the corresponding assets for flashloan.
     * @param _premiums list of premiums/fees for the corresponding addresses for flashloan.
     * @param _initiator initiator address for flashloan.
     * @param _data extra data passed.
     */
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external override verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(aaveLending), 'not aave sender');

        (uint16 route_, address sender_, bytes memory data_) = abi.decode(_data, (uint16, address, bytes));

        uint256[] memory _fees = calculateFees(_amounts, calculateFeeBPS(route_));
        uint256[] memory _initialBalances = calculateBalances(_assets, address(this));

        safeApprove(_assets, _amounts, _premiums, address(aaveLending));
        safeTransfer(_assets, _amounts, sender_);

        IFlashReceiver(sender_).executeOperation(_assets, _amounts, _fees, sender_, data_);

        uint256[] memory _finalBalances = calculateBalances(_assets, address(this));

        validateFlashloan(_initialBalances, _finalBalances, _fees);

        return true;
    }

    /**
     * @dev Fallback function for makerdao flashloan.
     * @param _initiator initiator address for flashloan.
     * _amount DAI amount for flashloan.
     * _fee fee for the flashloan.
     * @param _data extra data passed(includes route info aswell).
     */
    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external override verifyDataHash(_data) returns (bytes32) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(makerLending), 'not maker sender');

        (uint16 route_, address[] memory assets_, uint256[] memory amounts_, address sender_, bytes memory data_) = abi
            .decode(_data, (uint16, address[], uint256[], address, bytes));

        uint256[] memory _fees = calculateFees(amounts_, calculateFeeBPS(route_));
        uint256[] memory _initialBalances = calculateBalances(assets_, address(this));

        safeApprove(assets_, amounts_, _fees, address(makerLending));
        safeTransfer(assets_, amounts_, sender_);

        IFlashReceiver(sender_).executeOperation(assets_, amounts_, _fees, sender_, data_);
        uint256[] memory _finalBalances = calculateBalances(assets_, address(this));
        validateFlashloan(_initialBalances, _finalBalances, _fees);

        return keccak256('ERC3156FlashBorrower.onFlashLoan');
    }

    /**
     * @dev Fallback function for balancer flashloan.
     * _amounts list of amounts for the corresponding assets or amount of ether to borrow as collateral for flashloan.
     * _fees list of fees for the corresponding addresses for flashloan.
     * @param _data extra data passed(includes route info aswell).
     */
    function receiveFlashLoan(
        address[] memory,
        uint256[] memory,
        uint256[] memory _fees,
        bytes memory _data
    ) external override verifyDataHash(_data) {
        require(msg.sender == address(balancerLending), 'not balancer sender');

        (uint16 route_, address[] memory assets_, uint256[] memory amounts_, address sender_, bytes memory data_) = abi
            .decode(_data, (uint16, address[], uint256[], address, bytes));

        uint256[] memory fees_ = calculateFees(amounts_, calculateFeeBPS(route_));
        uint256[] memory initialBalances_ = calculateBalances(assets_, address(this));

        safeTransfer(assets_, amounts_, sender_);
        IFlashReceiver(sender_).executeOperation(assets_, amounts_, fees_, sender_, data_);

        uint256[] memory _finalBalances = calculateBalances(assets_, address(this));

        validateFlashloan(initialBalances_, _finalBalances, fees_);
        safeTransferWithFee(assets_, amounts_, _fees, address(balancerLending));
    }

    /**
     * @dev Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @param _tokens token addresses for flashloan.
     * @param _amounts list of amounts for the corresponding assets.
     * @param _route route for flashloan.
     * @param _data extra data passed.
     */
    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint16 _route,
        bytes calldata _data,
        bytes calldata
    ) external override reentrancy {
        require(_tokens.length == _amounts.length, 'array-lengths-not-same');

        validateTokens(_tokens);

        if (_route == ROUTE_AAVE) {
            routeAave(_tokens, _amounts, _data);
        } else if (_route == ROUTE_MAKER) {
            routeMaker(_tokens, _amounts, _data);
        } else if (_route == ROUTE_BALANCER) {
            routeBalancer(_tokens, _amounts, _data);
        } else {
            revert('route-does-not-exist');
        }

        emit LogFlashloan(msg.sender, _route, _tokens, _amounts);
    }

    receive() external payable {}

    /* ============ Public Functions ============ */

    /**
     * @dev Returns fee for the passed route in BPS.
     * @notice Returns fee for the passed route in BPS. 1 BPS == 0.01%.
     * @param _route route number for flashloan.
     */
    function calculateFeeBPS(uint256 _route) public view override returns (uint256 BPS) {
        if (_route == ROUTE_AAVE) {
            BPS = aaveLending.FLASHLOAN_PREMIUM_TOTAL();
        } else if (_route == ROUTE_MAKER) {
            BPS = (makerLending.toll()) / (10 ** 14);
        } else if (_route == ROUTE_BALANCER) {
            BPS = (balancerLending.getProtocolFeesCollector().getFlashLoanFeePercentage()) * 100;
        } else {
            revert('invalid route');
        }
    }

    /**
     * @dev Function to get the list of available routes.
     * @notice Function to get the list of available routes.
     */
    function getRoutes() public pure override returns (uint16[] memory routes) {
        routes = new uint16[](3);
        routes[0] = 1;
        routes[1] = 2;
        routes[2] = 3;
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Middle function for route 1.
     * @param _tokens list of token addresses for flashloan.
     * @param _amounts list of amounts for the corresponding assets or
     * amount of ether to borrow as collateral for flashloan.
     * @param _data extra data passed.
     */
    function routeAave(address[] memory _tokens, uint256[] memory _amounts, bytes memory _data) internal {
        bytes memory data_ = abi.encode(ROUTE_AAVE, msg.sender, _data);
        uint256 length_ = _tokens.length;
        uint256[] memory _modes = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            _modes[i] = 0;
        }
        _dataHash = bytes32(keccak256(data_));
        aaveLending.flashLoan(address(this), _tokens, _amounts, _modes, address(0), data_, 0);
    }

    /**
     * @dev Middle function for route 2.
     * @param _tokens token address for flashloan(DAI).
     * @param _amounts DAI amount for flashloan.
     * @param _data extra data passed.
     */
    function routeMaker(address[] memory _tokens, uint256[] memory _amounts, bytes memory _data) internal {
        bytes memory data_ = abi.encode(ROUTE_MAKER, _tokens, _amounts, msg.sender, _data);
        _dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(IERC3156FlashBorrower(address(this)), _tokens[0], _amounts[0], data_);
    }

    /**
     * @dev Middle function for route 3.
     * @param _tokens token addresses for flashloan.
     * @param _amounts list of amounts for the corresponding assets.
     * @param _data extra data passed.
     */
    function routeBalancer(address[] memory _tokens, uint256[] memory _amounts, bytes memory _data) internal {
        bytes memory data_ = abi.encode(ROUTE_BALANCER, _tokens, _amounts, msg.sender, _data);
        _dataHash = bytes32(keccak256(data_));

        balancerLending.flashLoan(IFlashLoanRecipient(address(this)), _tokens, _amounts, data_);
    }

    /**
     * @dev Approves the tokens to the receiver address with allowance (amount + fee).
     * @notice Approves the tokens to the receiver address with allowance (amount + fee).
     * @param _tokens list of token addresses for the respective tokens.
     * @param _amounts List of balances for the respective tokens.
     * @param _fees list of premiums/fees for the corresponding addresses for flashloan.
     * @param _receiver address to which tokens have to be approved.
     */
    function safeApprove(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _fees,
        address _receiver
    ) internal {
        uint256 length_ = _tokens.length;
        require(length_ == _amounts.length, 'Lengths of parameters not same');
        require(length_ == _fees.length, 'Lengths of parameters not same');

        for (uint256 i = 0; i < length_; i++) {
            IERC20(_tokens[i]).universalApprove(_receiver, _amounts[i] + _fees[i]);
        }
    }

    /**
     * @dev Transfers the tokens to the receiver address.
     * @notice Transfers the tokens to the receiver address.
     * @param _tokens list of token addresses to calculate balance for.
     * @param _amounts List of balances for the respective tokens.
     * @param _receiver address to which tokens have to be transferred.
     */
    function safeTransfer(address[] memory _tokens, uint256[] memory _amounts, address _receiver) internal {
        uint256 length_ = _tokens.length;
        require(length_ == _amounts.length, 'Lengths of parameters not same');

        for (uint256 i = 0; i < length_; i++) {
            IERC20(_tokens[i]).universalTransfer(_receiver, _amounts[i]);
        }
    }

    /**
     * @dev Transfers the tokens to the receiver address (amount + fee).
     * @notice Transfers the tokens to the receiver address (amount + fee).
     * @param _tokens list of token addresses to calculate balance for.
     * @param _amounts List of balances for the respective tokens.
     * @param _fees list of fees for the respective tokens.
     * @param _receiver address to which tokens have to be transferred.
     */
    function safeTransferWithFee(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _fees,
        address _receiver
    ) internal {
        uint256 length_ = _tokens.length;
        require(length_ == _amounts.length, 'Lengths of parameters not same');
        require(length_ == _fees.length, 'Lengths of parameters not same');

        for (uint256 i = 0; i < length_; i++) {
            IERC20(_tokens[i]).universalTransfer(_receiver, _amounts[i] + _fees[i]);
        }
    }

    /**
     * @dev Calculates the balances.
     * @notice Calculates the balances of the account passed for the tokens.
     * @param _tokens list of token addresses to calculate balance for.
     * @param _account account to calculate balance for.
     */
    function calculateBalances(address[] memory _tokens, address _account) internal view returns (uint256[] memory) {
        uint256 _length = _tokens.length;
        uint256[] memory balances_ = new uint256[](_length);
        for (uint256 i = 0; i < _length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            balances_[i] = token.balanceOf(_account);
        }
        return balances_;
    }

    /**
     * @dev Validates if the receiver sent the correct amounts of funds.
     * @notice Validates if the receiver sent the correct amounts of funds.
     * @param _initialBalances List of initial balances for the respective tokens.
     * @param _finalBalances List of  final balances for the respective tokens.
     * @param _fees List of fees for the respective tokens.
     */
    function validateFlashloan(
        uint256[] memory _initialBalances,
        uint256[] memory _finalBalances,
        uint256[] memory _fees
    ) internal pure {
        for (uint256 i = 0; i < _initialBalances.length; i++) {
            require(_initialBalances[i] + _fees[i] <= _finalBalances[i], 'amount paid less');
        }
    }

    /**
     * @dev Validates if token addresses are unique. Just need to check adjacent tokens as the array was sorted first
     * @notice Validates if token addresses are unique.
     * @param _tokens list of token addresses.
     */
    function validateTokens(address[] memory _tokens) internal pure {
        for (uint256 i = 0; i < _tokens.length - 1; i++) {
            require(_tokens[i] != _tokens[i + 1], 'non unique tokens');
        }
    }

    /**
     * @dev Calculate fees for the respective amounts and fee in BPS passed.
     * @notice Calculate fees for the respective amounts and fee in BPS passed. 1 BPS == 0.01%.
     * @param _amounts list of amounts.
     * @param _BPS fee in BPS.
     */
    function calculateFees(uint256[] memory _amounts, uint256 _BPS) internal pure returns (uint256[] memory) {
        uint256 length_ = _amounts.length;

        uint256[] memory fees = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            fees[i] = (_amounts[i] * _BPS) / (10 ** 4);
        }
        return fees;
    }
}
