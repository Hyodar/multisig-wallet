// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/MultisigWallet.sol";

contract MultisigWalletScript is Script {
    function run() public {
        address[] memory members = new address[](5);

        for (uint160 i = 0; i < members.length; i++) {
            members[i] = address(i);
        }

        members[0] = msg.sender;

        vm.broadcast();
        new MultisigWallet(members, 1);
    }
}
