// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/EdgePushOracle.sol";

contract DeployEdgePushOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        EdgePushOracle oracle = new EdgePushOracle();
        oracle.initialize(8, "EDGE_PUSH_ORACLE", owner);

        vm.stopBroadcast();
    }
}
