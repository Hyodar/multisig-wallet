// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../library/MemberList.sol";

/// @title Multisig membership management logic
/// @author Hyodar
/// @notice Manages members and provides related utility functions
abstract contract MembershipManager {
    using MemberList for MemberList.List;

    /// @notice Member list
    MemberList.List internal _members;

    /// @notice Required approvals in order to execute a transaction
    /// @custom:security write-protection="onlyWallet()"
    uint256 public requiredApprovals;

    /// @notice Emitted when a member is added
    /// @param account Newly added member
    event MemberAdded(address indexed account);

    /// @notice Emitted when a member is removed
    /// @param account Newly removed member
    event MemberRemoved(address indexed account);

    /// @notice Emitted when the wallet's required approvals value is changed
    event RequiredApprovalsChanged(uint256 previous, uint256 current);

    /// @notice Checks whether the msg.sender is the wallet address
    modifier onlyWallet() {
        require(msg.sender == address(this), "Wallet-specific operation");
        _;
    }

    /// @notice Checks whether the msg.sender is a member
    modifier onlyMember() {
        require(isMember(msg.sender), "Member-specific operation");
        _;
    }

    /// @notice Checks whether a member count and required approvals setup is
    ///     valid - that is, if both are different from 0 and the required
    ///     approvals value is not greater than the member count.
    modifier validSetup(uint256 _memberCount, uint256 requiredApprovals_) {
        require(
            _memberCount != 0 && requiredApprovals_ != 0,
            "There should be at least one member and at least one approval should be required"
        );
        require(
            requiredApprovals_ <= _memberCount,
            "Required approvals should not be greater than the amount of members"
        );
        _;
    }

    /// @notice Adds a wallet member
    /// @dev Can only be called by the wallet itself, the account must not be
    ///     a member and must not be the zero address
    /// @param account The account address to be added as member
    function addMember(address account) external onlyWallet {
        _addMember(account);
    }

    /// @notice Removes a wallet member
    /// @dev Can only be called by the wallet itself, the account must be a
    ///     member
    /// @param account The account address to be removed from the member list
    function removeMember(address account) external onlyWallet {
        _removeMember(account);
    }

    /// @notice Replaces a wallet member with another address
    /// @dev Can only be called by the wallet itself, the `from` account must
    ///     be a member and the `to` account must not be a member and must not
    ///     be the zero address
    /// @param from The current member to be replaced
    /// @param to The non-member that will replace `from`
    function replaceMember(address from, address to) external onlyWallet {
        _replaceMember(from, to);
    }

    /// @notice Sets the required approvals in order for a transaction to be
    ///     executed
    /// @dev Can only be called by the wallet itself and the final setup of
    ///     member count and required approvals must be valid. Refer to
    ///     {MembershipManager-validSetup}
    function setRequiredApprovals(uint256 requiredApprovals_)
        external
        onlyWallet
    {
        _setRequiredApprovals(requiredApprovals_);
    }

    /// @notice Gets the members list as an array
    /// @dev Results in a (possibly large) array copy.
    function getMembers() external view returns (address[] memory) {
        return _members.values();
    }

    /// @notice Checks whether an account is a member or not
    /// @dev Uses an underlying map in order to do this, so no O(n) required
    function isMember(address account) public view returns (bool) {
        return _members.contains(account);
    }

    /// @notice Gets the amount of members
    function memberCount() public view returns (uint256) {
        return _members.length();
    }

    /// @notice Gets a member from its index
    function _getMember(uint256 index) internal view returns (address) {
        return _members.at(index);
    }

    /// @notice Adds an account address to the member list
    /// @dev The account must not be a member and must not be the zero address
    /// @param account The account address to be added
    function _addMember(address account) internal {
        _members.add(account);

        emit MemberAdded(account);
    }

    /// @notice Removes an account address from the member list
    /// @dev The account must be a member
    /// @param account The account address to be removed
    function _removeMember(address account)
        internal
        validSetup(_members.length() - 1, requiredApprovals)
    {
        _members.remove(account);

        emit MemberRemoved(account);
    }

    /// @notice Replaces an account address in the member list with another
    ///     address
    /// @dev The `from` account must be a member and the `to` account must not
    ///     be a member and must not be the zero address
    /// @param from The current member to be replaced
    /// @param to The non-member that will replace `from`
    function _replaceMember(address from, address to) internal {
        _members.replace(from, to);

        emit MemberRemoved(from);
        emit MemberAdded(to);
    }

    /// @notice Sets the required approvals in order for a transaction to be
    ///     executed
    /// @dev The final setup of member count and required approvals must be
    ///     valid. Refer to {MembershipManager-validSetup}
    function _setRequiredApprovals(uint256 requiredApprovals_)
        internal
        validSetup(_members.length(), requiredApprovals_)
    {
        emit RequiredApprovalsChanged(requiredApprovals, requiredApprovals_);
        requiredApprovals = requiredApprovals_;
    }

    /// @notice Sets up the initial membership data
    /// @dev The members array must be a non-empty array with no repeated
    ///     entries and must not have any zero addresses. The required
    ///     approvals must not be zero and must be at most the length of
    ///     `members`.
    function _setupMembership(
        address[] memory members,
        uint256 requiredApprovals_
    )
        internal
    {
        for (uint256 i = 0; i < members.length; i++) {
            _addMember(members[i]);
        }

        _setRequiredApprovals(requiredApprovals_);
    }
}
