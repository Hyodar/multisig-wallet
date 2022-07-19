// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {
    function setUp() public {}

    function testConstructorParametersLoaded() public {
        uint256 memberCount = 10;
        uint256 requiredApprovals = 2;
        address[] memory members = new address[](memberCount);

        for (uint160 i = 0; i < memberCount; i++) {
            members[i] = address(i);
        }

        MultisigWallet multisigWallet =
            new MultisigWallet(members, requiredApprovals);

        assertEq(multisigWallet.getMembers(), members);
        assertEq(multisigWallet.requiredApprovals(), requiredApprovals);
    }

    function testCannotRequireMoreApprovalsThanMembers() public {
        uint256 requiredApprovals = 2;
        address[] memory members = new address[](requiredApprovals - 1);

        vm.expectRevert(
            "Required approvals should not be greater than the amount of members"
        );
        new MultisigWallet(members, requiredApprovals);
    }
}
