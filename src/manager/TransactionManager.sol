// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../library/MemberList.sol";
import "../library/Operation.sol";
import "./MembershipManager.sol";

/// @title Multisig transaction proposal and execution logic
/// @author Hyodar
/// @notice Manages transactions and provides related utility functions
abstract contract TransactionManager is MembershipManager {
    using MemberList for MemberList.List;

    /// @notice All transaction proposals ever made in the wallet
    /// @custom:security write-protection="onlyMember()"
    TransactionProposal[] internal _transactionProposals;

    /// @notice Map that records, per transaction, the approvals of any addresses
    /// @custom:security write-protection="onlyMember()"
    mapping(uint256 => mapping(address => bool)) public transactionApprovedBy;

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
        uint256 refundAmount;
        bytes data;
    }

    /// @notice Emitted when a transaction proposal is created by a member
    /// @param member The address of the member that created the proposal
    /// @param transactionId The ID of the transaction proposal
    event TransactionProposalCreated(
        address indexed member,
        uint256 indexed transactionId
    );

    /// @notice Emitted when a transaction proposal is approved by a member
    /// @param member The address of the member that approved the proposal
    /// @param transactionId The ID of the transaction proposal being approved
    event TransactionProposalApproved(
        address indexed member,
        uint256 indexed transactionId
    );

    /// @notice Emitted when a transaction proposal approval is revoked by a
    ///     member
    /// @param member The address of the member that revoked its approval
    /// @param transactionId The ID of the previously approved transaction proposal
    event TransactionProposalApprovalRevoked(
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

    /// @notice Checks whether a transaction proposal has passed (i.e. its
    ///     member approvals are greater than or equal to the required
    ///     approvals)
    /// @dev Expensive operation, O(n)
    modifier proposalPassed(uint256 transactionId) {
        uint256 _memberCount = memberCount();
        uint256 approvals = 0;

        unchecked {
            // nothing can realistically overflow here
            for (
                uint256 i = 0;
                i < _memberCount && approvals < requiredApprovals;
                i++
            ) {
                if (transactionApprovedBy[transactionId][_members.at(i)]) {
                    approvals++;
                }
            }
        }

        require(approvals >= requiredApprovals, "Not enough approvals");

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
            "This transaction has already been executed"
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
        bytes calldata data,
        uint256 refundAmount
    )
        public
        onlyMember
    {
        if (operation == Operation.DELEGATE_CALL) {
            require(value == 0, "Cannot send value in delegatecall");
        }

        _transactionProposals.push(
            TransactionProposal({
                to: to,
                operation: operation,
                executed: false,
                value: value,
                data: data,
                refundAmount: refundAmount
            })
        );

        unchecked {
            // _transactionProposals.length > 0
            emit TransactionProposalCreated(
                msg.sender, _transactionProposals.length - 1
                );
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
        bytes calldata data,
        uint256 refundAmount
    )
        external
        onlyMember
    {
        proposeTransaction(to, operation, value, data, refundAmount);

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
        emit TransactionProposalApproved(msg.sender, transactionId);
    }

    /// @notice Revokes a previous transaction proposal approval
    /// @dev Can only be called by a member, requires that the proposal is
    ///     still open to voting and that the proposal was already approved by
    ///     this member
    /// @param transactionId ID of the transaction proposal to have the
    ///      sender's approval revoked
    function revokeApproval(uint256 transactionId)
        external
        onlyMember
        proposalExists(transactionId)
        proposalOpen(transactionId)
    {
        require(
            transactionApprovedBy[transactionId][msg.sender],
            "Sender didn't approve this proposal"
        );

        transactionApprovedBy[transactionId][msg.sender] = false;
        emit TransactionProposalApprovalRevoked(msg.sender, transactionId);
    }

    /// @notice Executes a transaction whose proposal has passed voting
    /// @dev Can only be called by a member, requires that the proposal
    ///     is still open and already has at least the required approvals.
    ///     None of the calls should allow reentering execute() with the
    ///     same transaction since when those happen the transaction is
    ///     already marked as executed, so proposalOpen() would revert.
    ///     Refer to {MultisigWalletTest-testCannotReenterExecuteWithTheSameTransaction}
    /// @param transactionId ID of the transaction proposal to be executed
    function execute(uint256 transactionId)
        external
        onlyMember
        proposalExists(transactionId)
        proposalOpen(transactionId)
        proposalPassed(transactionId)
    {
        TransactionProposal storage transaction =
            _transactionProposals[transactionId];
        transaction.executed = true;

        bool success;

        // emit first so the event order stays the same even if the first call
        // leads to another execute() somehow
        emit TransactionProposalExecuted(msg.sender, transactionId);

        if (transaction.operation == Operation.CALL) {
            // slither-disable-next-line low-level-calls
            (success,) = address(transaction.to).call{
                value: transaction.value,
                gas: gasleft()
            }(transaction.data);
        } else {
            // slither-disable-next-line low-level-calls
            (success,) = address(transaction.to).delegatecall{gas: gasleft()}(
                transaction.data
            );
        }

        require(success, "Transaction was not successful");

        uint256 refundAmount = transaction.refundAmount;

        if (refundAmount != 0) {
            (success,) = msg.sender.call{value: refundAmount}("");
            require(success, "Refund was not successful");
        }
    }

    /// @notice Gets a transaction proposal through its ID
    function getTransactionProposal(uint256 transactionId)
        external
        view
        returns (TransactionProposal memory)
    {
        return _transactionProposals[transactionId];
    }

    /// @notice Gets the amount of transaction proposals made in this wallet
    function getTransactionProposalCount() external view returns (uint256) {
        return _transactionProposals.length;
    }

    /// @notice Gets the members that approved a transaction proposal
    /// @param transactionId The ID of the transaction proposal
    function getApprovingMembers(uint256 transactionId)
        external
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
