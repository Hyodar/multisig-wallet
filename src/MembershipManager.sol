// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./MemberList.sol";

abstract contract MembershipManager {
    using MemberList for MemberList.List;

    MemberList.List internal _members;
    uint256 public requiredApprovals;

    event MemberAdded(address account);
    event MemberRemoved(address account);
    event RequiredApprovalsChanged(uint256 previous, uint256 current);

    modifier onlyWallet() {
        require(msg.sender == address(this), "Wallet-specific operation");
        _;
    }

    modifier validSetup(uint256 _memberCount, uint256 _requiredApprovals) {
        require(
            _memberCount != 0 && _requiredApprovals != 0,
            "There should be at least one member and at least one approval should be required"
        );
        require(
            _requiredApprovals <= _memberCount,
            "Required approvals should not be greater than the amount of members"
        );
        _;
    }

    function addMember(address account) public onlyWallet {
        require(_members.add(account));

        emit MemberAdded(account);
    }

    function removeMember(address account)
        public
        onlyWallet
        validSetup(_members.length() - 1, requiredApprovals)
    {
        require(_members.remove(account));

        emit MemberRemoved(account);
    }

    function replaceMember(address from, address to) public onlyWallet {
        require(_members.replace(from, to));

        emit MemberRemoved(from);
        emit MemberAdded(to);
    }

    function setRequiredApprovals(uint256 _requiredApprovals)
        public
        onlyWallet
        validSetup(_members.length(), _requiredApprovals)
    {
        emit RequiredApprovalsChanged(requiredApprovals, _requiredApprovals);
        requiredApprovals = _requiredApprovals;
    }

    function getMembers() public view returns (address[] memory) {
        return _members.values();
    }

    function isMember(address account) public view returns (bool) {
        return _members.contains(account);
    }

    function memberCount() public view returns (uint256) {
        return _members.length();
    }

    function _setupMembership(
        address[] memory members,
        uint256 _requiredApprovals
    )
        internal
        validSetup(members.length, _requiredApprovals)
    {
        for (uint256 i = 0; i < members.length; i++) {
            require(_members.add(members[i]));
        }

        emit RequiredApprovalsChanged(requiredApprovals, _requiredApprovals);
        requiredApprovals = _requiredApprovals;
    }
}
