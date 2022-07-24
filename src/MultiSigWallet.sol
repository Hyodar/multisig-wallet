// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./manager/TransactionManager.sol";
import "./manager/FallbackManager.sol";

/// @title A cool multisig wallet
/// @author Hyodar
/// @notice A contract that basically works as a shared wallet, allowing a
///     group of members to participate in a form of on-chain quorum to vote
///     on transactions to be executed by the wallet
contract MultisigWallet is TransactionManager, FallbackManager {
    constructor(address[] memory members, uint256 requiredApprovals_) {
        _setupMembership(members, requiredApprovals_);
    }
}
