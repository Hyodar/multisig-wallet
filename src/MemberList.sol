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

    function add(List storage list, address account) internal returns (bool) {
        if (contains(list, account) || account == address(0)) {
            return false;
        }

        list._members.push(account);
        list._memberOrder[account] = list._members.length;

        return true;
    }

    function remove(List storage list, address account)
        internal
        returns (bool)
    {
        uint256 removedMemberOrder = list._memberOrder[account];

        if (removedMemberOrder == 0) return false;

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

        return true;
    }

    function replace(List storage list, address from, address to)
        internal
        returns (bool)
    {
        uint256 replacedMemberOrder = list._memberOrder[from];

        if (replacedMemberOrder == 0 || contains(list, to) || to == address(0))
        {
            return false;
        }

        unchecked {
            // replacedMemberOrder > 0
            list._members[replacedMemberOrder - 1] = to;
        }

        list._memberOrder[to] = replacedMemberOrder;
        delete list._memberOrder[from];

        return true;
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
