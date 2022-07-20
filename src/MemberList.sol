// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title An enumerable map-like member container
/// @author Hyodar
/// @notice This library can be used for storing members and cheaply checking
///     if an address is a member or not
library MemberList {
    struct List {
        address[] _members;
        // order as 1-indexed positions, since entries that are not set are 0
        mapping(address => uint256) _memberOrder;
    }

    /// @notice Checks whether an account is a member or not
    /// @dev Uses an underlying map in order to do this, so no O(n) required
    /// @param self The List instance
    /// @param account The account address to be checked
    function contains(List storage self, address account)
        internal
        view
        returns (bool)
    {
        return self._memberOrder[account] != 0;
    }

    /// @notice Adds an account address to the member list
    /// @dev The account must not be a member and must not be the zero address
    /// @param self The List instance
    /// @param account The account address to be added
    function add(List storage self, address account) internal {
        require(!contains(self, account), "Account is already a member");
        require(account != address(0), "Zero address can't be added as member");

        self._members.push(account);
        self._memberOrder[account] = self._members.length;
    }

    /// @notice Removes an account address from the member list
    /// @dev The account must be a member
    /// @param self The List instance
    /// @param account The account address to be removed
    function remove(List storage self, address account) internal {
        uint256 removedMemberOrder = self._memberOrder[account];

        require(removedMemberOrder != 0, "Account is not a member");

        uint256 memberCount = self._members.length;

        if (removedMemberOrder != memberCount) {
            address lastMember;

            unchecked {
                // there is at least one member, memberCount > 0
                lastMember = self._members[memberCount - 1];

                // removedMemberOrder > 0
                self._members[removedMemberOrder - 1] = lastMember;
            }

            self._memberOrder[lastMember] = removedMemberOrder;
        }

        self._members.pop();
        delete self._memberOrder[account];
    }

    /// @notice Replaces an account address in the member list with another
    ///     address
    /// @dev The `from` account must be a member and the `to` account must not
    ///     be a member and must not be the zero address
    /// @param self The List instance
    /// @param from The current member to be replaced
    /// @param to The non-member that will replace `from`
    function replace(List storage self, address from, address to) internal {
        require(!contains(self, to), "Account is already a member");
        require(to != address(0), "Zero address can't be added as member");

        uint256 replacedMemberOrder = self._memberOrder[from];
        require(replacedMemberOrder != 0, "Replaced account is not a member");

        unchecked {
            // replacedMemberOrder > 0
            self._members[replacedMemberOrder - 1] = to;
        }

        self._memberOrder[to] = replacedMemberOrder;
        delete self._memberOrder[from];
    }

    /// @notice Gets the member at a specified position in the array
    /// @dev `index` must be less than the members list length
    /// @param self The List instance
    /// @param index The index in the members array
    function at(List storage self, uint256 index)
        internal
        view
        returns (address)
    {
        return self._members[index];
    }

    /// @notice Gets the underlying members array
    /// @dev Results in a (possibly large) array copy. Prefer {MemberList-at}
    ///     when possible.
    /// @param self The List instance
    function values(List storage self)
        internal
        view
        returns (address[] memory)
    {
        return self._members;
    }

    /// @notice Gets the amount of members
    /// @param self The List instance
    function length(List storage self) internal view returns (uint256) {
        return self._members.length;
    }
}
