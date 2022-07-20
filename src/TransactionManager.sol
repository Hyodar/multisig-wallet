// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./MemberList.sol";
import "./MembershipManager.sol";

/// @title Multisig transaction proposal and execution logic
/// @author Hyodar
/// @notice Manages transactions and provides related utility functions
abstract contract TransactionManager is MembershipManager {
    using MemberList for MemberList.List;

    /// @notice Container for transaction proposal information
    /// @member to Destination of the transaction that would be executed
    /// @member executed Flag that indicates whether a transaction has already
    ///     been executed or not
    /// @member value The ether value to be sent in the transaction
    /// @member data The encoded transaction data
    struct Transaction {
        address to;
        bool executed;
        uint256 value;
        bytes data;
    }

    /// @notice The transactions array
    Transaction[] public transactions;

    /// @notice Emitted when a proposal is approved by a member
    /// @param member The address of the member that approved the proposal
    /// @param transactionId The ID of the transaction proposal being approved
    event ProposalApproved(
        address indexed member,
        uint256 indexed transactionId
    );

    /// @notice Emitted when a proposal approval is revoked by a member
    /// @param member The address of the member that revoked its approval
    /// @param transactionId The ID of the previously approved transaction proposal
    event ProposalRevoked(address indexed member, uint256 indexed transactionId);

    /// @notice Map that records, per transaction, the approvals of any addresses
    mapping(uint256 => mapping(address => bool)) transactionApprovedBy;

    /// @notice Checks whether a transaction proposal has passed (i.e. it's
    ///     member approvals are greater than or equal to the required
    ///     approvals)
    /// @dev Expensive operation, O(n)
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

    /// @notice Checks whether a transaction proposal is still open to voting
    ///     (i.e. it hasn't yet been executed)
    modifier proposalOpen(uint256 transactionId) {
        require(transactionId < transactions.length, "Unknown proposal");
        require(
            !transactions[transactionId].executed,
            "This transaction was already executed"
        );
        _;
    }

    /// @notice Approves a transaction proposal
    /// @dev Can only be called from a member, requires that the proposal is
    ///     still open to voting and that the proposal wasn't yet approved by
    ///     this member
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

    /// @notice Revokes a previous transaction proposal approval
    /// @dev Can only be called from a member, requires that the proposal is
    ///     still open to voting and that the proposal was already approved by
    ///     this member
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
