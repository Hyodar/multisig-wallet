// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../library/MemberList.sol";
import "../library/Operation.sol";
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
        Operation operation;
        uint256 value;
        bytes data;
    }

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
    event ProposalApprovalRevoked(
        address indexed member,
        uint256 indexed transactionId
    );

    /// @notice Emitted when a transaction proposal is executed by a member
    /// @param member The address of the member that executed the proposal
    /// @param transactionId The ID of the executed transaction proposal
    event TransactionProposalExecuted(
        address indexed member,
        uint256 indexed transactionId
    );

    /// @notice All transaction proposals ever made in the wallet
    TransactionProposal[] internal _transactionProposals;

    /// @notice Map that records, per transaction, the approvals of any addresses
    mapping(uint256 => mapping(address => bool)) public transactionApprovedBy;

    /// @notice Checks whether a transaction proposal has passed (i.e. its
    ///     member approvals are greater than or equal to the required
    ///     approvals)
    /// @dev Expensive operation, O(n)
    modifier proposalPassed(uint256 transactionId) {
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

        require(approvals >= requiredApprovals, "");

        _;
    }

    /// @notice Checks whether a transaction proposal exists in the list
    modifier proposalExists(uint256 transactionId) {
        require(
            transactionId < _transactionProposals.length, "Unknown proposal"
        );
        _;
    }

    /// @notice Checks whether a transaction proposal is still open to voting
    ///     (i.e. it hasn't yet been executed)
    modifier proposalOpen(uint256 transactionId) {
        require(
            !_transactionProposals[transactionId].executed,
            "This transaction was already executed"
        );
        _;
    }

    /// @notice Opens a transaction for voting
    /// @dev Can only be called by a member
    /// @param to Call destination
    /// @param operation Operation type (call or delegatecall)
    /// @param value Ether value to be sent in the call
    /// @param data Encoded call data
    function proposeTransaction(
        address to,
        Operation operation,
        uint256 value,
        bytes calldata data
    )
        public
        onlyMember
    {
        _transactionProposals.push(
            TransactionProposal({
                to: to,
                operation: operation,
                executed: false,
                value: value,
                data: data
            })
        );

        unchecked {
            // _transactionProposals.length > 0
            emit ProposalCreated(msg.sender, _transactionProposals.length - 1);
        }
    }

    /// @notice Opens a transaction for voting and approves it
    /// @dev Can only be called by a member
    /// @param to Call destination
    /// @param operation Operation type (call or delegatecall)
    /// @param value Ether value to be sent in the call
    /// @param data Encoded call data
    function proposeAndApprove(
        address to,
        Operation operation,
        uint256 value,
        bytes calldata data
    )
        public
        onlyMember
    {
        proposeTransaction(to, operation, value, data);

        unchecked {
            // _transactionProposals.length > 0
            approve(_transactionProposals.length - 1);
        }
    }

    /// @notice Approves a transaction proposal
    /// @dev Can only be called by a member, requires that the proposal is
    ///     still open to voting and that the proposal wasn't yet approved by
    ///     this member
    /// @param transactionId ID of the transaction proposal to be approved
    function approve(uint256 transactionId)
        public
        onlyMember
        proposalExists(transactionId)
        proposalOpen(transactionId)
    {
        require(
            !transactionApprovedBy[transactionId][msg.sender],
            "Sender already approved this proposal"
        );

        transactionApprovedBy[transactionId][msg.sender] = true;
        emit ProposalApproved(msg.sender, transactionId);
    }

    /// @notice Revokes a previous transaction proposal approval
    /// @dev Can only be called by a member, requires that the proposal is
    ///     still open to voting and that the proposal was already approved by
    ///     this member
    /// @param transactionId ID of the transaction proposal to have the
    ///      sender's approval revoked
    function revokeApproval(uint256 transactionId)
        public
        onlyMember
        proposalExists(transactionId)
        proposalOpen(transactionId)
    {
        require(
            transactionApprovedBy[transactionId][msg.sender],
            "Sender didn't approve this proposal"
        );

        transactionApprovedBy[transactionId][msg.sender] = false;
        emit ProposalApprovalRevoked(msg.sender, transactionId);
    }

    /// @notice Executes a transaction whose proposal has passed voting
    /// @dev Can only be called by a member, requires that the proposal
    ///     is still open and already has at least the required approvals
    /// @param transactionId ID of the transaction proposal to be executed
    function execute(uint256 transactionId)
        public
        onlyMember
        proposalExists(transactionId)
        proposalOpen(transactionId)
        proposalPassed(transactionId)
    {
        uint256 previousGas = gasleft();

        TransactionProposal storage transaction =
            _transactionProposals[transactionId];
        transaction.executed = true;

        bool success;

        if (transaction.operation == Operation.CALL) {
            (success,) = address(transaction.to).call{
                value: transaction.value,
                gas: gasleft()
            }(transaction.data);
        } else {
            (success,) = address(transaction.to).delegatecall{gas: gasleft()}(
                transaction.data
            );
        }

        require(success, "Transaction was not successful");
        emit TransactionProposalExecuted(msg.sender, transactionId);

        // refund msg.sender approximately the eth amount spent
        (success,) =
            msg.sender.call{value: (previousGas - gasleft()) * tx.gasprice}("");

        require(success, "Refund was not successful");
    }

    /// @notice Gets a transaction proposal through its ID
    function getTransactionProposal(uint256 transactionId)
        public
        view
        returns (TransactionProposal memory)
    {
        return _transactionProposals[transactionId];
    }

    /// @notice Gets the amount of transaction proposals made in this wallet
    function getTransactionProposalCount() public view returns (uint256) {
        return _transactionProposals.length;
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
