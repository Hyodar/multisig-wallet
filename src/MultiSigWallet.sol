// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract MultisigWallet {
    event Deposit(address indexed from, uint256 value);

    address[] public members;
    uint256 public immutable requiredApprovals;

    constructor(address[] memory _members, uint256 _requiredApprovals) {
        require(
            _members.length != 0 && _requiredApprovals != 0,
            "There should be at least one member and at least one approval should be required"
        );
        require(
            _requiredApprovals <= _members.length,
            "Required approvals should not be greater than the amount of members"
        );

        members = _members;
        requiredApprovals = _requiredApprovals;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function getMembers() public view returns (address[] memory) {
        return members;
    }
}
