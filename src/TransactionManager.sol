// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./MemberList.sol";
import "./MembershipManager.sol";

abstract contract TransactionManager is MembershipManager {
    struct Transaction {
        address to;
        bool executed;
        uint256 value;
        bytes data;
    }

    Transaction[] public transactions;

    using MemberList for MemberList.List;

    event ProposalApproved(
        address indexed member,
        uint256 indexed transactionId
    );
    event ProposalRevoked(address indexed member, uint256 indexed transactionId);

    mapping(uint256 => mapping(address => bool)) transactionApprovedBy;

    modifier votePassed(uint256 transactionId) {
        uint256 memberCount = _members.length();
        uint256 approvals = 0;

        unchecked {
            // nothing can realistically overflow here
            for (
                uint256 i = 0; i < memberCount && approvals < requiredApprovals; i++
            ) {
                if (transactionApprovedBy[transactionId][_members.at(i)]) {
                    approvals++;
                }
            }
        }

        require(approvals >= requiredApprovals, "Not enough approvals");

        _;
    }

    modifier proposalOpen(uint256 transactionId) {
        require(transactionId < transactions.length, "Unknown proposal");
        require(
            !transactions[transactionId].executed,
            "This transaction was already executed"
        );
        _;
    }

    function approve(uint256 transactionId)
        public
        onlyMember
        proposalOpen(transactionId)
    {
        require(
            !transactionApprovedBy[transactionId][msg.sender],
            "Sender already approved this proposal"
        );
        transactionApprovedBy[transactionId][msg.sender] = true;
    }

    function revoke(uint256 transactionId)
        public
        onlyMember
        proposalOpen(transactionId)
    {
        require(
            transactionApprovedBy[transactionId][msg.sender],
            "Sender didn't approve this proposal"
        );
        transactionApprovedBy[transactionId][msg.sender] = false;
    }
}
