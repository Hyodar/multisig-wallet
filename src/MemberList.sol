// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

library MemberList {
    struct List {
        address[] _members;
        // order as 1-indexed positions, since entries that are not set are 0
        mapping(address => uint256) _memberOrder;
    }

    function contains(List storage list, address account)
        internal
        view
        returns (bool)
    {
        return list._memberOrder[account] != 0;
    }

    function add(List storage list, address account) internal {
        require(!contains(list, account), "Account is already a member");
        require(account != address(0), "Zero address can't be added as member");

        list._members.push(account);
        list._memberOrder[account] = list._members.length;
    }

    function remove(List storage list, address account) internal {
        uint256 removedMemberOrder = list._memberOrder[account];

        require(removedMemberOrder != 0, "Account is not a member");

        uint256 memberCount = list._members.length;

        if (removedMemberOrder != memberCount) {
            address lastMember;

            unchecked {
                // there is at least one member, memberCount > 0
                lastMember = list._members[memberCount - 1];

                // removedMemberOrder > 0
                list._members[removedMemberOrder - 1] = lastMember;
            }

            list._memberOrder[lastMember] = removedMemberOrder;
        }

        list._members.pop();
        delete list._memberOrder[account];
    }

    function replace(List storage list, address from, address to) internal {
        require(!contains(list, to), "Account is already a member");
        require(to != address(0), "Zero address can't be added as member");

        uint256 replacedMemberOrder = list._memberOrder[from];
        require(replacedMemberOrder != 0, "Replaced account is not a member");

        unchecked {
            // replacedMemberOrder > 0
            list._members[replacedMemberOrder - 1] = to;
        }

        list._memberOrder[to] = replacedMemberOrder;
        delete list._memberOrder[from];
    }

    function at(List storage list, uint256 index)
        internal
        view
        returns (address)
    {
        return list._members[index];
    }

    function values(List storage list)
        internal
        view
        returns (address[] memory)
    {
        return list._members;
    }

    function length(List storage list) internal view returns (uint256) {
        return list._members.length;
    }
}
