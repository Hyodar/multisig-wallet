// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract MultisigWallet {
    address[] public members;
    uint256 public immutable requiredApprovals;

    constructor(address[] memory _members, uint256 _requiredApprovals) {
        require(
            _requiredApprovals <= _members.length,
            "Required approvals should not be greater than the amount of members"
        );

        members = _members;
        requiredApprovals = _requiredApprovals;
    }

    function getMembers() public view returns (address[] memory) {
        return members;
    }
}
