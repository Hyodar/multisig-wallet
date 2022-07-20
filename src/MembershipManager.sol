// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./MemberList.sol";

abstract contract MembershipManager {
    using MemberList for MemberList.List;

    MemberList.List internal _members;
    uint256 public requiredApprovals;

    event MemberAdded(address indexed account);
    event MemberRemoved(address indexed account);
    event RequiredApprovalsChanged(uint256 previous, uint256 current);

    modifier onlyWallet() {
        require(msg.sender == address(this), "Wallet-specific operation");
        _;
    }

    modifier onlyMember() {
        require(isMember(msg.sender), "Member-specific operation");
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
        _addMember(account);
    }

    function removeMember(address account) public onlyWallet {
        _removeMember(account);
    }

    function replaceMember(address from, address to) public onlyWallet {
        _replaceMember(from, to);
    }

    function setRequiredApprovals(uint256 _requiredApprovals)
        public
        onlyWallet
    {
        _setRequiredApprovals(_requiredApprovals);
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

    function _addMember(address account) internal {
        require(_members.add(account));

        emit MemberAdded(account);
    }

    function _removeMember(address account)
        internal
        validSetup(_members.length() - 1, requiredApprovals)
    {
        require(_members.remove(account));

        emit MemberRemoved(account);
    }

    function _replaceMember(address from, address to) internal {
        require(_members.replace(from, to));

        emit MemberRemoved(from);
        emit MemberAdded(to);
    }

    function _setRequiredApprovals(uint256 _requiredApprovals)
        internal
        validSetup(_members.length(), _requiredApprovals)
    {
        emit RequiredApprovalsChanged(requiredApprovals, _requiredApprovals);
        requiredApprovals = _requiredApprovals;
    }

    function _setupMembership(
        address[] memory members,
        uint256 _requiredApprovals
    )
        internal
    {
        for (uint256 i = 0; i < members.length; i++) {
            _addMember(members[i]);
        }

        _setRequiredApprovals(_requiredApprovals);
    }
}
