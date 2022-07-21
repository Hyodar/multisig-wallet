// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../src/MultisigWallet.sol";
import "../src/library/Operation.sol";

contract MultisigWalletTest is Test {
    event Deposit(address indexed from, uint256 value);
    event MemberAdded(address indexed account);
    event MemberRemoved(address indexed account);
    event RequiredApprovalsChanged(uint256 previous, uint256 current);
    event ProposalCreated(address indexed member, uint256 indexed transactionId);
    event ProposalApproved(
        address indexed member,
        uint256 indexed transactionId
    );

    uint256 constant MEMBER_COUNT = 10;
    uint256 constant REQUIRED_APPROVALS = 7;
    address[] members;

    MultisigWallet multisigWallet;

    function setUp() public {
        // some assertions that assure the following tests will work as expected
        assertLt(REQUIRED_APPROVALS, MEMBER_COUNT);
        assertGt(MEMBER_COUNT, 0);
        assertGt(REQUIRED_APPROVALS, 0);

        for (uint160 i = 1; i <= MEMBER_COUNT; i++) {
            members.push(address(i));

            vm.expectEmit(true, false, false, true);
            emit MemberAdded(address(i));
        }

        vm.expectEmit(false, false, false, true);
        emit RequiredApprovalsChanged(0, REQUIRED_APPROVALS);

        multisigWallet = new MultisigWallet(members, REQUIRED_APPROVALS);

        vm.deal(address(multisigWallet), 1e18);
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

    // Constructor
    // -----------------------------------------------------------------------

    function testConstructorParametersLoaded() public {
        assertEq(multisigWallet.getMembers(), members);
        assertEq(multisigWallet.requiredApprovals(), REQUIRED_APPROVALS);
    }

    function testCannotDeployWithZeroAddressMember() public {
        address[] memory _members = new address[](1);

        vm.expectRevert("Zero address can't be added as member");
        new MultisigWallet(_members, 1);
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

    // Depositing
    // -----------------------------------------------------------------------

    function testEtherDeposit() public {
        uint256 value = 10 ether;
        vm.deal(address(this), value);

        uint256 previousBalance = address(multisigWallet).balance;

        vm.expectEmit(true, false, false, true, address(multisigWallet));
        emit Deposit(address(this), value);

        (bool success,) = address(multisigWallet).call{value: value}("");
        assertTrue(success);

        assertEq(address(multisigWallet).balance, previousBalance + value);
    }

    // Member addition
    // -----------------------------------------------------------------------

    function testCannotAddMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.addMember(address(0xdef1));
    }

    function testCannotAddZeroAddressMember() public {
        vm.expectRevert("Zero address can't be added as member");
        vm.prank(address(multisigWallet));
        multisigWallet.addMember(address(0));
    }

    function testCannotAddExistingMember() public {
        vm.expectRevert("Account is already a member");
        vm.prank(address(multisigWallet));
        multisigWallet.addMember(members[0]);
    }

    function testAddMember() public {
        vm.expectEmit(true, false, false, true, address(multisigWallet));
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
        vm.expectEmit(true, false, false, true, address(multisigWallet));
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
        vm.expectRevert("Zero address can't be added as member");
        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(members[0], address(0));
    }

    function testReplaceMember() public {
        vm.expectEmit(true, false, false, true, address(multisigWallet));
        emit MemberRemoved(members[0]);

        vm.expectEmit(true, false, false, true, address(multisigWallet));
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
        vm.expectEmit(true, false, false, true, address(multisigWallet));
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
            address(0xdef1), Operation.CALL, 0 ether, ""
        );
    }

    function testCannotProposeAndApproveTransactionIfNotMember() public {
        vm.expectRevert("Member-specific operation");
        multisigWallet.proposeAndApprove(
            address(0xdef1), Operation.CALL, 0 ether, ""
        );
    }

    function testProposeTransaction() public {
        address member = members[0];

        vm.expectEmit(true, true, false, false, address(multisigWallet));
        emit ProposalCreated(member, 0);

        vm.prank(member);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 1 ether, "data"
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
        address member = members[0];

        vm.expectEmit(true, true, false, false, address(multisigWallet));
        emit ProposalCreated(member, 0);

        vm.expectEmit(true, true, true, false, address(multisigWallet));
        emit ProposalApproved(member, 0);

        vm.prank(member);
        multisigWallet.proposeAndApprove(
            address(0xdef1), Operation.CALL, 1 ether, "data"
        );

        TransactionManager.TransactionProposal memory transaction =
            multisigWallet.getTransactionProposal(0);

        assertEq(transaction.to, address(0xdef1));
        assertFalse(transaction.executed);
        assertEq(uint8(transaction.operation), uint8(Operation.CALL));
        assertEq(transaction.value, 1 ether);
        assertEq(transaction.data, "data");
        assertTrue(multisigWallet.transactionApprovedBy(0, member));
    }

    // Approving transaction proposals
    // -----------------------------------------------------------------------

    function testCannotApproveTransactionProposalIfNotMember() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, "data"
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
            address(0xdef1), Operation.CALL, 0 ether, "data"
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
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, members[0]);

        vm.prank(members[0]);
        multisigWallet.execute(0);

        vm.expectRevert("This transaction was already executed");
        vm.prank(members[0]);
        multisigWallet.approve(0);
    }

    function testApproveTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, members[0]);

        vm.prank(members[0]);
        multisigWallet.approve(0);

        assertTrue(multisigWallet.transactionApprovedBy(0, members[0]));
    }

    // Rekoving transaction proposal approvals
    // -----------------------------------------------------------------------

    function testCannotRevokeApprovalOnTransactionProposalIfNotMember() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, "data"
        );

        vm.expectRevert("Member-specific operation");
        multisigWallet.revokeApproval(0);
    }

    function testCannotRevokeApprovalOnUnexistingTransactionProposal() public {
        vm.expectRevert("Unknown proposal");
        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);
    }

    function testCannotRevokeApprovalOnNonApprovedTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, "data"
        );

        vm.expectRevert("Sender didn't approve this proposal");
        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);
    }

    function testCannotRevokeApprovalOnAlreadyExecutedTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(multisigWallet),
            Operation.CALL,
            0 ether,
            abi.encodeWithSignature("addMember(address)", address(0xdef1))
        );

        _approveAll(0, members[0]);

        vm.prank(members[0]);
        multisigWallet.execute(0);

        vm.expectRevert("This transaction was already executed");
        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);
    }

    function testRevokeApprovalOnTransactionProposal() public {
        vm.prank(members[0]);
        multisigWallet.proposeTransaction(
            address(0xdef1), Operation.CALL, 0 ether, "data"
        );

        _approveAll(0, address(0));

        assertTrue(multisigWallet.transactionApprovedBy(0, members[0]));

        vm.prank(members[0]);
        multisigWallet.revokeApproval(0);

        assertFalse(multisigWallet.transactionApprovedBy(0, members[0]));
    }
}
