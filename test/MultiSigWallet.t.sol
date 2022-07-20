// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {
    event Deposit(address indexed from, uint256 value);
    event MemberAdded(address indexed account);
    event MemberRemoved(address indexed account);
    event RequiredApprovalsChanged(uint256 previous, uint256 current);

    uint256 constant MEMBER_COUNT = 10;
    uint256 constant REQUIRED_APPROVALS = 7;
    address[] members;

    MultisigWallet multisigWallet;

    function setUp() public {
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
    }

    function testConstructorParametersLoaded() public {
        assertEq(multisigWallet.getMembers(), members);
        assertEq(multisigWallet.requiredApprovals(), REQUIRED_APPROVALS);
    }

    function testCannotDeployWithZeroAddressMember() public {
        address[] memory _members = new address[](1);

        vm.expectRevert();
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

    function testCannotAddMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.addMember(address(0xdef1));
    }

    function testCannotAddZeroAddressMember() public {
        vm.expectRevert();
        vm.prank(address(multisigWallet));
        multisigWallet.addMember(address(0));
    }

    function testCannotAddExistingMember() public {
        vm.expectRevert();
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

    function testCannotRemoveMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.removeMember(members[0]);
    }

    function testCannotRemoveUnexistingMember() public {
        vm.expectRevert();
        vm.prank(address(multisigWallet));
        multisigWallet.removeMember(address(0xf00d));
    }

    function testCannotRemoveMemberIfRequiredApprovalsWouldBeGreaterThanMemberCount(
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

    function testCannotReplaceMemberIfNotWallet() public {
        vm.expectRevert("Wallet-specific operation");
        multisigWallet.replaceMember(members[0], address(0xdef1));
    }

    function testCannotReplaceUnexistingMember() public {
        vm.expectRevert();
        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(address(0xdef1), address(0xf00d));
    }

    function testCannotReplaceMemberWithMember() public {
        vm.expectRevert();
        vm.prank(address(multisigWallet));
        multisigWallet.replaceMember(members[0], members[1]);
    }

    function testCannotReplaceMemberWithZeroAddress() public {
        vm.expectRevert();
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
}
