// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "../src/MultisigWallet.sol";
import "../src/utils/Operation.sol";

contract StorageEditor {
    function editSlot(uint256 slot, uint256 value) public {
        assembly { sstore(slot, value) }
    }
}

contract Reverter {
    fallback() external payable {
        revert();
    }
}

contract ReentrantMember {
    fallback() external payable {
        MultisigWallet(payable(msg.sender)).execute(0);
    }
}

contract FallbackHandler {
    function handle(uint256 value) public pure returns (uint256) {
        return value;
    }
}

contract MultisigWalletTest is Test {
    event Deposit(address indexed from, uint256 value);
    event MemberAdded(address indexed account);
    event MemberRemoved(address indexed account);
    event RequiredApprovalsChanged(uint256 previous, uint256 current);
    event TransactionProposalCreated(
        address indexed member,
        uint256 indexed transactionId
    );
    event TransactionProposalApproved(
        address indexed member,
        uint256 indexed transactionId
    );
    event TransactionProposalApprovalRevoked(
        address indexed member,
        uint256 indexed transactionId
    );
    event TransactionProposalExecuted(
        address indexed member,
        uint256 indexed transactionId
    );
    event FallbackContractChanged(
        address indexed previous,
        address indexed current
    );

    uint256 constant MEMBER_COUNT = 10;
    uint256 constant REQUIRED_APPROVALS = 7;
    address[] members;

    MultisigWallet multisigWallet;
    StorageEditor storageEditor;
    Reverter reverter;
    FallbackHandler fallbackHandler;

    function setUp() public {
        // some assertions that assure the following tests will work as expected
        assertLt(REQUIRED_APPROVALS, MEMBER_COUNT);
        assertGt(MEMBER_COUNT, 0);
        assertGt(REQUIRED_APPROVALS, 0);

        for (uint160 i = 1; i <= MEMBER_COUNT; i++) {
            members.push(address(i));

            vm.expectEmit(true, true, true, true);
            emit MemberAdded(address(i));
        }

        vm.expectEmit(false, true, true, true);
        emit RequiredApprovalsChanged(0, REQUIRED_APPROVALS);

        multisigWallet = new MultisigWallet(members, REQUIRED_APPROVALS);
        storageEditor = new StorageEditor();
        reverter = new Reverter();
        fallbackHandler = new FallbackHandler();

        vm.deal(address(multisigWallet), 10 ether);
    }

    // Utils
    // -----------------------------------------------------------------------

    function _approveAll(uint256 transactionId, address besides) internal {
        address[] memory _members = multisigWallet.getMembers();

        for (uint256 i = 0; i < _members.length; i++) {
            if (_members[i] != besides) {
                vm.prank(_members[i]);
                multisigWallet.approve(transactionId);
            }
        }
    }

    function _computeCreateAddress(uint8 nonce)
        internal
        view
        returns (address)
    {
        require(nonce <= 0x7f);
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xd6),
                            bytes1(0x94),
                            address(this),
                            // added condition even though EIP161 states
                            // contract nonces start at 1
                            bytes1((nonce == 0) ? 0x80 : nonce)
                        )
                    )
                )
            )
        );
    }

    // Constructor
    // -----------------------------------------------------------------------

    function testConstructorParametersLoaded() public {
        assertEq(multisigWallet.getMembers(), members);
        assertEq(multisigWallet.requiredApprovals(), REQUIRED_APPROVALS);
    }

    function testCannotDeployWithZeroAddressMember() public {
        address[] memory _members = new address[](1);

        vm.expectRevert("Zero address cannot be added as member");
        new MultisigWallet(_members, 1);
    }

    function testCannotDeployWithWalletBeingAMember() public {
        address[] memory _members = new address[](1);
        _members[0] = _computeCreateAddress(5);

        vm.expectRevert("Wallet cannot be added as member");
        new MultisigWallet(_members, 1);
    }

    function testCannotDeployWithDuplicateMembers() public {
        address[] memory _members = new address[](2);
        _members[0] = address(0xdef1);
        _members[1] = address(0xdef1);

        vm.expectRevert("Account is already a member");
        new MultisigWallet(_members, 2);
    }

    function testCannotDeployWithEmptyMembersList() public {
        address[] memory _members = new address[](0);

        vm.expectRevert(
            "There should be at least one member and at least one approval should be required"
        );
        new MultisigWallet(_members, REQUIRED_APPROVALS);
    }

    function testCannotDeployWithNoRequiredApprovals() public {
        vm.expectRevert(
            "There should be at least one member and at least one approval should be required"
        );
        new MultisigWallet(members, 0);
    }

    function testCannotDeployRequiringMoreApprovalsThanMembers() public {
        uint256 requiredApprovals = MEMBER_COUNT + 1;

        vm.expectRevert(
            "Required approvals should not be greater than the amount of members"
        );
        new MultisigWallet(members, requiredApprovals);
    }

    // Depositing and fallback contract
    // -----------------------------------------------------------------------

    function testEtherDepositShouldNotEmitOnZeroDeposit() public {
        vm.recordLogs();

        (bool success,) = address(multisigWallet).call("");
        assertTrue(success);

        assertEq(vm.getRecordedLogs().length, 0);
    }

    function testEtherDeposit() public {
        uint256 value = 10 ether;
        vm.deal(address(this), value);

        uint256 previousBalance = address(multisigWallet).balance;

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit Deposit(address(this), value);

        (bool success,) = address(multisigWallet).call{value: value}("");
        assertTrue(success);

        assertEq(address(multisigWallet).balance, previousBalance + value);
    }

    function testCannotSetFallbackContractIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.setFallbackContract(address(0xdef1));
    }

    function testSetFallbackContract() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit FallbackContractChanged(address(0), address(0xdef1));

        vm.prank(address(multisigWallet));
        multisigWallet.setFallbackContract(address(0xdef1));

        assertEq(multisigWallet.fallbackContract(), address(0xdef1));
    }

    function testFallbackWithoutFallbackContractActsAsReceive() public {
        vm.recordLogs();
        (bool success, bytes memory returnData) =
            address(multisigWallet).call("data");

        assertTrue(success);
        assertEq(returnData, "");
        assertEq(vm.getRecordedLogs().length, 0);

        uint256 value = 20 ether;
        vm.deal(address(this), value);

        uint256 previousBalance = address(multisigWallet).balance;

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit Deposit(address(this), value);

        (success,) = address(multisigWallet).call{value: value}("data");
        assertTrue(success);

        assertEq(address(multisigWallet).balance, previousBalance + value);
    }

    function testFallbackRevertsOnFallbackContractRevert() public {
        vm.prank(address(multisigWallet));
        multisigWallet.setFallbackContract(address(reverter));
        assertEq(multisigWallet.fallbackContract(), address(reverter));

        (bool success,) = address(multisigWallet).call("data");
        assertFalse(success);
    }

    function testFallbackWithFallbackContractSetRedirectsCalls() public {
        vm.prank(address(multisigWallet));
        multisigWallet.setFallbackContract(address(fallbackHandler));
        assertEq(multisigWallet.fallbackContract(), address(fallbackHandler));

        (bool success, bytes memory returnData) = address(multisigWallet).call(
            abi.encodeWithSignature("handle(uint256)", 1)
        );

        assertTrue(success);

        (uint256 handledValue) = abi.decode(returnData, (uint256));

        assertEq(handledValue, 1);
    }

    // Member addition
    // -----------------------------------------------------------------------

    function testCannotAddMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.addMember(address(0xdef1));
    }

    function testCannotAddZeroAddressMember() public {
        vm.expectRevert("Zero address cannot be added as member");
        vm.prank(address(multisigWallet));
        multisigWallet.addMember(address(0));
    }

    function testCannotAddWalletAsMember() public {
        vm.expectRevert("Wallet cannot be added as member");
        vm.prank(address(multisigWallet));
        multisigWallet.addMember(address(multisigWallet));
    }

    function testCannotAddExistingMember() public {
        vm.expectRevert("Account is already a member");
        vm.prank(address(multisigWallet));
        multisigWallet.addMember(members[0]);
    }

    function testAddMember() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit MemberAdded(address(0xdef1));

        vm.prank(address(multisigWallet));
        multisigWallet.addMember(address(0xdef1));

        members.push(address(0xdef1));

        assertEq(multisigWallet.getMembers(), members);
    }

    // Member removal
    // -----------------------------------------------------------------------

    function testCannotRemoveMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.removeMember(members[0]);
    }

    function testCannotRemoveUnexistingMember() public {
        vm.expectRevert("Account is not a member");
        vm.prank(address(multisigWallet));
        multisigWallet.removeMember(address(0xf00d));
    }

    function testCannotRemoveMemberIfRequiredApprovalsWouldGetGreaterThanMemberCount(
    )
        public
    {
        for (uint256 i = MEMBER_COUNT - 1; i >= REQUIRED_APPROVALS; i--) {
            vm.prank(address(multisigWallet));
            multisigWallet.removeMember(members[i]);

            members[i] = members[members.length - 1];
            members.pop();
        }

        vm.expectRevert(
            "Required approvals should not be greater than the amount of members"
        );
        vm.prank(address(multisigWallet));
        multisigWallet.removeMember(members[0]);
    }

    function testRemoveMember() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit MemberRemoved(members[0]);

        vm.prank(address(multisigWallet));
        multisigWallet.removeMember(members[0]);

        members[0] = members[members.length - 1];
        members.pop();

        assertEq(multisigWallet.getMembers(), members);
    }

    // Member replacing
    // -----------------------------------------------------------------------

    function testCannotReplaceMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.replaceMember(members[0], address(0xdef1));
    }

    function testCannotReplaceUnexistingMember() public {
        vm.expectRevert("Replaced account is not a member");
        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(address(0xdef1), address(0xf00d));
    }

    function testCannotReplaceMemberWithMember() public {
        vm.expectRevert("Account is already a member");
        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(members[0], members[1]);
    }

    function testCannotReplaceMemberWithZeroAddress() public {
        vm.expectRevert("Zero address cannot be added as member");
        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(members[0], address(0));
    }

    function testReplaceMember() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit MemberRemoved(members[0]);

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit MemberAdded(address(0xdef1));

        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(members[0], address(0xdef1));

        members[0] = address(0xdef1);

        assertEq(multisigWallet.getMembers(), members);
    }

    // Setting required approvals
    // -----------------------------------------------------------------------

    function testCannotSetRequiredApprovalsIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.setRequiredApprovals(MEMBER_COUNT);
    }

    function testCannotSetRequiredApprovalsToZero() public {
        vm.expectRevert(
            "There should be at least one member and at least one approval should be required"
        );
        vm.prank(address(multisigWallet));
        multisigWallet.setRequiredApprovals(0);
    }

    function testCannotSetRequiredApprovalsToBeGreaterThanMemberCount()
        public
    {
        vm.expectRevert(
            "Required approvals should not be greater than the amount of members"
        );
        vm.prank(address(multisigWallet));
        multisigWallet.setRequiredApprovals(MEMBER_COUNT + 1);
    }

    function testSetRequiredApprovals() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit RequiredApprovalsChanged(REQUIRED_APPROVALS, MEMBER_COUNT - 1);

        vm.prank(address(multisigWallet));
        multisigWallet.setRequiredApprovals(MEMBER_COUNT - 1);

        assertEq(multisigWallet.requiredApprovals(), MEMBER_COUNT - 1);
    }

    // Creating transaction proposals
    // -----------------------------------------------------------------------

    function testCannotProposeTransactionIfNotMember() public {
        vm.expectRevert("Member-specific operation");
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, ""
        );
    }

    function testCannotProposeAndApproveTransactionIfNotMember() public {
        vm.expectRevert("Member-specific operation");
        multisigWallet.proposeAndApprove(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, ""
        );
    }

    function testCannotProposeDelegateCallTransactionWithNonZeroValue()
        public
    {
        vm.expectRevert("Cannot send value in delegatecall");
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.DELEGATE_CALL, 1 ether, 0 ether, ""
        );
    }

    function testProposeTransaction() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalCreated(members[0], 0);

        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 1 ether, 0 ether, "data"
        );

        TransactionManager.TransactionProposal memory transaction =
            multisigWallet.getTransactionProposal(0);

        assertEq(transaction.to, address(0xdef1));
        assertFalse(transaction.executed);
        assertEq(uint8(transaction.operation), uint8(Operation.CALL));
        assertEq(transaction.value, 1 ether);
        assertEq(transaction.data, "data");
    }

    function testProposeAndApproveTransaction() public {
        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalCreated(members[0], 0);

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalApproved(members[0], 0);

        vm.prank(members[0]);
        multisigWallet.proposeAndApprove(
            address(0xdef1), Operation.CALL, 1 ether, 0 ether, "data"
        );

        TransactionManager.TransactionProposal memory transaction =
            multisigWallet.getTransactionProposal(0);

        assertEq(transaction.to, address(0xdef1));
        assertFalse(transaction.executed);
        assertEq(uint8(transaction.operation), uint8(Operation.CALL));
        assertEq(transaction.value, 1 ether);
        assertEq(transaction.data, "data");
        assertTrue(multisigWallet.transactionApprovedBy(0, members[0]));
    }

    // Approving transaction proposals
    // -----------------------------------------------------------------------

    function testCannotApproveTransactionProposalIfNotMember() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        vm.expectRevert("Member-specific operation");
        multisigWallet.approve(0);
    }

    function testCannotApproveUnexistingTransactionProposal() public {
        vm.expectRevert("Unknown proposal");
        vm.prank(members[0]);
        multisigWallet.approve(0);
    }

    function testCannotApproveAlreadyApprovedTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeAndApprove(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        vm.expectRevert("Sender already approved this proposal");
        vm.prank(members[0]);
        multisigWallet.approve(0);
    }

    function testCannotApproveAlreadyExecutedTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            0 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, members[0]);

        vm.prank(members[0]);
        multisigWallet.execute(0);

        vm.expectRevert("This transaction has already been executed");
        vm.prank(members[0]);
        multisigWallet.approve(0);
    }

    function testApproveTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            0 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, members[0]);

        assertFalse(multisigWallet.transactionApprovedBy(0, members[0]));

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalApproved(members[0], 0);

        vm.prank(members[0]);
        multisigWallet.approve(0);

        assertTrue(multisigWallet.transactionApprovedBy(0, members[0]));
    }

    // Rekoving transaction proposal approvals
    // -----------------------------------------------------------------------

    function testCannotRevokeApprovalOnTransactionProposalIfNotMember()
        public
    {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        vm.expectRevert("Member-specific operation");
        multisigWallet.revokeApproval(0);
    }

    function testCannotRevokeApprovalOnUnexistingTransactionProposal() public {
        vm.expectRevert("Unknown proposal");
        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);
    }

    function testCannotRevokeApprovalOnNonApprovedTransactionProposal()
        public
    {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        vm.expectRevert("Sender didn't approve this proposal");
        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);
    }

    function testCannotRevokeApprovalOnAlreadyExecutedTransactionProposal()
        public
    {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            0 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, members[0]);

        vm.prank(members[0]);
        multisigWallet.execute(0);

        vm.expectRevert("This transaction has already been executed");
        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);
    }

    function testRevokeApprovalOnTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        _approveAll(0, address(0));

        assertTrue(multisigWallet.transactionApprovedBy(0, members[0]));

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalApprovalRevoked(members[0], 0);

        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);

        assertFalse(multisigWallet.transactionApprovedBy(0, members[0]));
    }

    // Executing transaction proposals
    // -----------------------------------------------------------------------

    function testCannotExecuteTransactionProposalIfNotMember() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        _approveAll(0, address(0));

        vm.expectRevert("Member-specific operation");
        multisigWallet.execute(0);
    }

    function testCannotExecuteUnexistingTransactionProposal() public {
        vm.prank(members[0]);
        vm.expectRevert("Unknown proposal");
        multisigWallet.execute(0);
    }

    function testCannotExecuteAlreadyExecutedTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            0 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, address(0));

        vm.prank(members[0]);
        multisigWallet.execute(0);
        assertEq(multisigWallet.getMembers()[MEMBER_COUNT], address(0xdef1));

        members.push(address(0xdef1));

        vm.prank(members[0]);
        vm.expectRevert("This transaction has already been executed");
        multisigWallet.execute(0);
    }

    function testCannotExecuteNonSufficientlyApprovedTransactionProposal()
        public
    {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, 0 ether, "data"
        );

        for (uint256 i = 0; i < REQUIRED_APPROVALS - 1; i++) {
            vm.prank(members[i]);
            multisigWallet.approve(0);
        }

        vm.prank(members[0]);
        vm.expectRevert("Not enough approvals");
        multisigWallet.execute(0);
    }

    function testCannotExecuteUnsuccessfulCall() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(reverter), Operation.CALL, 1 ether, 0 ether, "data"
        );

        _approveAll(0, address(0));

        vm.prank(members[0]);
        vm.expectRevert("Transaction was not successful");
        multisigWallet.execute(0);
    }

    function testCannotExecuteUnsuccessfulDelegateCall() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(reverter), Operation.DELEGATE_CALL, 0 ether, 0 ether, "data"
        );

        _approveAll(0, address(0));

        vm.expectRevert("Transaction was not successful");
        vm.prank(members[0]);
        multisigWallet.execute(0);
    }

    function testCannotExecuteIfNotEnoughEtherToSend() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1),
            Operation.CALL,
            address(multisigWallet).balance + 1,
            0 ether,
            "data"
        );

        _approveAll(0, address(0));

        vm.expectRevert("Transaction was not successful");
        vm.prank(members[0]);
        multisigWallet.execute(0);
    }

    function testCannotExecuteIfNotEnoughEtherToRefund() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1),
            Operation.CALL,
            address(multisigWallet).balance,
            1 wei,
            "data"
        );

        _approveAll(0, address(0));

        vm.expectRevert("Refund was not successful");
        vm.prank(members[0]);
        multisigWallet.execute(0);
    }

    function testCannotReenterExecuteWithTheSameTransaction() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            1 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        ReentrantMember reentrantMember = new ReentrantMember();
        vm.etch(members[0], address(reentrantMember).code);

        _approveAll(0, address(0));

        vm.prank(members[0]);
        multisigWallet.execute(0);

        vm.expectRevert("This transaction has already been executed");
        vm.prank(members[0]);
        multisigWallet.execute(0);
    }

    function testExecuteCallTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            1 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        uint256 previousBalance = address(members[0]).balance;

        _approveAll(0, address(0));

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalExecuted(members[0], 0);

        vm.prank(members[0]);
        multisigWallet.execute(0);

        uint256 refundAmount = address(members[0]).balance - previousBalance;

        assertEq(refundAmount, 1 ether);
        assertEq(multisigWallet.getMembers()[MEMBER_COUNT], address(0xdef1));
    }

    function testExecuteDelegateCallTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(storageEditor),
            Operation.DELEGATE_CALL,
            0 ether,
            1.5 ether,
            abi.encodeWithSignature("editSlot(uint256,uint256)", 0xdef1, 0xf00d)
        );

        uint256 previousBalance = address(members[0]).balance;

        _approveAll(0, address(0));

        vm.expectEmit(true, true, true, true, address(multisigWallet));
        emit TransactionProposalExecuted(members[0], 0);

        vm.prank(members[0]);
        multisigWallet.execute(0);

        uint256 refundAmount = address(members[0]).balance - previousBalance;

        assertEq(refundAmount, 1.5 ether);
        assertEq(
            vm.load(address(multisigWallet), bytes32(uint256(0xdef1))),
            bytes32(uint256(0xf00d))
        );
    }
}
