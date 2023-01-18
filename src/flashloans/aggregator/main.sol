// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./helpers.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FlashAggregator is Helper {
    using SafeERC20 for IERC20;

    event LogFlashloan(
        address indexed account,
        uint256 indexed route,
        address[] tokens,
        uint256[] amounts
    );
    
    receive() external payable {}

    /**
     * @notice Callback function for aave flashloan.
     */
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), "not-same-sender");
        require(msg.sender == address(aaveLending), "not-aave-sender");

        FlashloanVariables memory loanVariables_;

        (address sender_, bytes memory data_) = abi.decode(
            _data,
            (address, bytes)
        );

        loanVariables_._tokens = _assets;
        loanVariables_._amounts = _amounts;
        loanVariables_._fees = calculateFees(
            _amounts,
            calculateFeeBPS(1)
        );
        loanVariables_._iniBals = calculateBalances(
            _assets,
            address(this)
        );

        safeApprove(loanVariables_, _premiums, address(aaveLending));
        safeTransfer(loanVariables_, sender_);

        FlashReceiverInterface(sender_).executeOperation(
                _assets,
                _amounts,
                loanVariables_._fees,
                sender_,
                data_
            );

        loanVariables_._finBals = calculateBalances(
            _assets,
            address(this)
        );
        validateFlashloan(loanVariables_);

        return true;
    }

    /**
     * @notice Fallback function for makerdao flashloan.
     */
    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external verifyDataHash(_data) returns (bytes32) {
        require(_initiator == address(this), "not-same-sender");
        require(msg.sender == address(makerLending), "not-maker-sender");

        FlashloanVariables memory loanVariables_;

        (
            uint256 route_,
            address[] memory tokens_,
            uint256[] memory amounts_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data, (uint256, address[], uint256[], address, bytes));

        loanVariables_._tokens = tokens_;
        loanVariables_._amounts = amounts_;
        loanVariables_._iniBals = calculateBalances(
            tokens_,
            address(this)
        );
        loanVariables_._fees = calculateFees(
            amounts_,
            calculateFeeBPS(route_)
        );

        safeTransfer(loanVariables_, sender_);
        FlashReceiverInterface(sender_).executeOperation(
                tokens_,
                amounts_,
                loanVariables_._fees,
                sender_,
                data_
            );

        loanVariables_._finBals = calculateBalances(
            tokens_,
            address(this)
        );
        validateFlashloan(loanVariables_);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
    
    /**
     * @notice Fallback function for balancer flashloan.
     */
    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory,
        uint256[] memory _fees,
        bytes memory _data
    ) external verifyDataHash(_data) {
        require(msg.sender == address(balancerLending), "not-balancer-sender");

        FlashloanVariables memory loanVariables_;

        (
            uint256 route_,
            address[] memory tokens_,
            uint256[] memory amounts_,
            address sender_,
            bytes memory data_
        ) = abi.decode(_data, (uint256, address[], uint256[], address, bytes));

        loanVariables_._tokens = tokens_;
        loanVariables_._amounts = amounts_;
        loanVariables_._iniBals = calculateBalances(
            tokens_,
            address(this)
        );
        loanVariables_._fees = calculateFees(
            amounts_,
            calculateFeeBPS(route_)
        );

        safeTransfer(loanVariables_, sender_);
        FlashReceiverInterface(sender_).executeOperation(
                tokens_,
                amounts_,
                loanVariables_._fees,
                sender_,
                data_
            );

        loanVariables_._finBals = calculateBalances(
            tokens_,
            address(this)
        );

        validateFlashloan(loanVariables_);
            safeTransferWithFee(
                loanVariables_,
                _fees,
                address(balancerLending)
            );
    }

    /**
     * @notice Middle function for route 1.
     */
    function routeAave(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(msg.sender, _data);
        uint256 length_ = _tokens.length;
        uint256[] memory _modes = new uint256[](length_);
        for (uint256 i = 0; i < length_; i++) {
            _modes[i] = 0;
        }
        dataHash = bytes32(keccak256(data_));
        aaveLending.flashLoan(
            address(this),
            _tokens,
            _amounts,
            _modes,
            address(0),
            data_,
            0
        );
    }

    /**
     * @notice Middle function for route 2.
     */
    function routeMaker(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        bytes memory data_ = abi.encode(
            2,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        dataHash = bytes32(keccak256(data_));
        makerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            _tokens[0],
            _amounts[0],
            data_
        );
    }

    /**
     * @notice Middle function for route 5.
     */
    function routeBalancer(
        address[] memory _tokens,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        uint256 length_ = _tokens.length;
        IERC20[] memory tokens_ = new IERC20[](length_);
        for (uint256 i = 0; i < length_; i++) {
            tokens_[i] = IERC20(_tokens[i]);
        }
        bytes memory data_ = abi.encode(
            5,
            _tokens,
            _amounts,
            msg.sender,
            _data
        );
        dataHash = bytes32(keccak256(data_));

        balancerLending.flashLoan(
            FlashReceiverInterface(address(this)),
            tokens_,
            _amounts,
            data_
        );
    }

    /**
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     */
    function flashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _route,
        bytes calldata _data,
        bytes calldata 
    ) external reentrancy {
        require(_tokens.length == _amounts.length, "array-lengths-not-same");

        (_tokens, _amounts) = bubbleSort(_tokens, _amounts);
        validateTokens(_tokens);

        if (_route == 1) {
            routeAave(_tokens, _amounts, _data);
        } else if (_route == 2) {
            routeMaker(_tokens, _amounts, _data);
        } else if (_route == 3) {
            routeBalancer(_tokens, _amounts, _data);
        }

        emit LogFlashloan(msg.sender, _route, _tokens, _amounts);
    }

    /**
     * @notice Function to get the list of available routes.
     */
    function getRoutes() public pure returns (uint16[] memory routes_) {
        routes_ = new uint16[](3);
        routes_[0] = 1;
        routes_[1] = 2;
        routes_[2] = 3;
    }

    /**
     * @notice Function to transfer fee to the treasury. Will be called manually.
     */
    function transferFeeToTreasury(address[] memory _tokens) public {
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token_ = IERC20(_tokens[i]);
            uint256 decimals_ = TokenInterface(_tokens[i]).decimals();
            uint256 amtToSub_ = decimals_ == 18 ? 1e10 : decimals_ > 12
                ? 10000
                : decimals_ > 7
                ? 100
                : 10;
            uint256 amtToTransfer_ = token_.balanceOf(address(this)) > amtToSub_
                ? (token_.balanceOf(address(this)) - amtToSub_)
                : 0;
            if (amtToTransfer_ > 0)
                token_.safeTransfer(treasuryAddr, amtToTransfer_);
        }
    }
}
