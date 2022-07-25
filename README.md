# Multisig Wallet

This repository contains a simple implementation of a multisig wallet with on-chain approvals.

The contract acts as a shared wallet for multiple members. Any member can submit a transaction proposal that, when executed, will make a call or a delegated call with the information that was set in the proposal. A transaction can only be executed by a member (not necessarily the one that created the proposal) when it has been approved by at least a defined number of members. Approvals can also be revoked as long as the proposal hasn't been executed yet.

Besides external calls, there is also a number of wallet administrative operations that can only be executed through these proposals, such as adding or removing or replacing members, changing the approval threshold or setting a fallback contract that can extend the wallet's functionalities (e.g. implementing a specific callback).

An instance of this contract was deployed in the Goerli testnet at [`0xd02e968d8122d690b06aa9ad12db51d62f39f34a`](https://goerli.etherscan.io/address/0xd02e968d8122d690b06aa9ad12db51d62f39f34a). The deployment script is available at `script/MultisigWallet.s.sol`.

## Usage

To be able to build the project, run tests and other utilities, install [foundry](https://github.com/foundry-rs/foundry).

### Build
Build the contracts:

```
forge build
```

### Test
Run the unit tests:

```
forge test
```
