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
    struct TransactionProposal {
        address to;
        bool executed;
        uint256 value;
        bytes data;
    }

    /// @notice All transaction proposals ever made in the wallet
    TransactionProposal[] public transactionProposals;

    /// @notice Emitted when a proposal is created by a member
    /// @param member The address of the member that created the proposal
    /// @param transactionId The ID of the transaction proposal
    event ProposalCreated(address indexed member, uint256 indexed transactionId);

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
        require(transactionId < transactionProposals.length, "Unknown proposal");
        require(
            !transactionProposals[transactionId].executed,
            "This transaction was already executed"
        );
        _;
    }

    /// @notice Opens a transaction for voting
    /// @dev Can only be called from a member
    /// @param to Call destination
    /// @param value Ether value to be sent in the call
    /// @param data Encoded call data
    function proposeTransaction(address to, uint256 value, bytes calldata data)
        public
        onlyMember
    {
        transactionProposals.push(
            TransactionProposal({to: to, executed: false, value: value, data: data})
        );

        unchecked {
            // transactionProposals.length > 0
            emit ProposalCreated(msg.sender, transactionProposals.length - 1);
        }
    }

    /// @notice Opens a transaction for voting and approves it
    /// @dev Can only be called from a member
    /// @param to Call destination
    /// @param value Ether value to be sent in the call
    /// @param data Encoded call data
    function proposeAndApprove(address to, uint256 value, bytes calldata data)
        public
        onlyMember
    {
        proposeTransaction(to, value, data);

        unchecked {
            // transactionProposals.length > 0
            approve(transactionProposals.length - 1);
        }
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
    function revokeApproval(uint256 transactionId)
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

    /// @notice Gets the amount of transaction proposals made in this wallet
    function getTransactionProposalCount() public view returns (uint256) {
        return transactionProposals.length;
    }

    /// @notice Gets the members that approved a transaction proposal
    /// @param transactionId The ID of the transaction proposal
    function getApprovingMembers(uint256 transactionId)
        public
        view
        returns (address[] memory)
    {
        uint256 _memberCount = memberCount();
        address[] memory _approvingMembers = new address[](_memberCount);
        uint256 approvals = 0;

        unchecked {
            // nothing could realistically overflow in here
            for (uint256 i = 0; i < _memberCount; i++) {
                address member = _getMember(i);

                if (transactionApprovedBy[transactionId][member]) {
                    _approvingMembers[approvals++] = member;
                }
            }
        }

        address[] memory approvingMembers = new address[](approvals);

        unchecked {
            // nothing could realistically overflow in here
            for (uint256 i = 0; i < approvals; i++) {
                approvingMembers[i] = _approvingMembers[i];
            }
        }

        return approvingMembers;
    }
}
