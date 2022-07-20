// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./TransactionManager.sol";

contract MultisigWallet is TransactionManager {
    event Deposit(address indexed from, uint256 value);

    constructor(address[] memory members, uint256 requiredApprovals) {
        _setupMembership(members, requiredApprovals);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
