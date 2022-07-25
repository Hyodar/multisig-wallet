# Multisig Wallet

This repository contains a simple implementation of a multisig wallet with on-chain approvals.

The contract acts as a shared wallet for multiple members. Any member can submit a transaction proposal that, when executed, will make a call or a delegated call with the information that was set in the proposal. A transaction can only be executed by a member (not necessarily the one that created the proposal) when it has been approved by at least a defined number of members. Approvals can also be revoked as long as the proposal hasn't been executed yet.

Besides external calls, there is also a number of wallet administrative operations that can only be executed through these proposals, such as adding or removing or replacing members, changing the approval threshold or setting a fallback contract that can extend the wallet's functionalities (e.g. implementing a specific callback).

An instance of this contract was deployed in the Goerli testnet at [`0xe37eb278bde1cea9c1fe32a40d0ba160d3a94592`](https://goerli.etherscan.io/address/0xe37eb278bde1cea9c1fe32a40d0ba160d3a94592).
