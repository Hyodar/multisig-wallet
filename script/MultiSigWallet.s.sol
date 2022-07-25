// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import "../src/MultisigWallet.sol";

contract MultisigWalletScript is Script {
    function run() public {
        address[] memory members = new address[](3);

        members[0] = 0x43Ebb448B90Ae5cfEBa16C3c315Ff486f8Ef3CB6;
        members[1] = 0xa5563257778b3AAd74EaF50d17342f2fBF81437D;
        members[2] = 0xf8290AdAeFef3DcC51A46F256c6cd560c75E7D94;

        vm.broadcast();
        new MultisigWallet(members, 2);
    }
}
