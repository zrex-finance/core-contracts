# <img src="logo.svg" alt="NFTxCards" height="40px">
[![codecov](https://codecov.io/gh/Leverage-Aggregator/core-contracts/branch/master/graph/badge.svg?token=94VIK7W295)](https://codecov.io/gh/Leverage-Aggregator/core-contracts)

## Overview of the protocol

The protocol creates leveraged positions in existing lending protocols, providing leverage on the means of flash loans.

## Open position process overview

To create a leveraged position, the user must have a collateral token from the list of available tokens on the Lending Protocols. This token will be a collateral to open a trade and it will calculate the PnL position. 

If the user does not have a token from the list, the flash flow protocol will be able to exchange any user token from the list. Directly in the opening of the position without additional trades.

- choose a token based on the CF and LL of that token and available liquidity.
- look for a loan based on the token, amount and loan fee.
- look for a trade and prepare a stake date for it.
- we put together a coldata for a trade, a short-term loan, a deposit and a loan.
- the user gives an uproot to the protocol contract. (if the token supports it, it can only be signed)
- trade execution (position opening).

### Domain model

**Possiton**:

- `address` account - owner
- `address` debt - token for the loan
- `address` collateral - security token
- `uint256` amountIn - original amount of the position
- `uint256` sizeDelta - leverage
- `uint256` collateralAmount - amount for the collateral received after the trade 
- `uint256` borrowAmount - amount of the loan for the redemption of the short-term loan and calculation of the fund

**SwapParams**:

- `address` fromToken - input token
- `address` toToken - output token
- `uint256` amount - exchange amount
- `string` targetName - connector name
- `bytes` data - coldata for the exchange

### Commission calculation

- for each position opening, the commission is calculated based on the leveraged transaction amount and the commission set on the contract, the commission can only be changed by the ovner.

### Router

- position opening and creation of proxy accounts for users.
- Accounts are created by cloning a Proxy contract when a position is opened and the user has no account.
- open and closing a position in a token that is not present in the LendingProtocols, there are methods by which we can make the exchange before opening or after closing a position.
- It stores the data of all user accounts and positions.

### Account

- contains the logic for opening and closing positions.
*Account contains the logic for opening and closing positions.*

### AddressesProvider

- it gives all the other contracts the address of the contracts.
- sets addresses for all main contracts in the protocol.
- in the future it will create proxy contracts and update their implementations.

### Connectors

- sets the addresses for support contracts for interactions with other protocols.

### Implementations

- sets the address for the implementation that the proxy account gets.
*Implementations will be merged with AddressesProvider in the future*

### Mapping

- serves as the storage for the compoundV2 tokens.

### FlashAggregator

- is used to take and return flash loans.
- It works with aave, balancer, maker.
- the parameters are calculated using the FlashResolver contract (in the future they will be calculated on the backend)

### FlashResolver

- calculates the parameters for working with FlashAggregator

### Connector

- contains the minimal logic for working with external protocols
- they are handled by delegatecall
*There's a thought of making libraries out of them*

### License

Smart contracts for NFTxCards protocol are available under the [MIT License](LICENSE.md).
