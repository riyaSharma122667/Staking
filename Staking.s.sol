// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Staking.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        Staking staking = new Staking(
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
            0x9D7f74d0C41E726EC95884E0e97Fa6129e3b5E99
        );

        console.log("Staking deployed at:", address(staking));

        vm.stopBroadcast();
    }
}
