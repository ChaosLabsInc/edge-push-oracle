// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/EdgePushOracle.sol";

contract DeployEdgePushOracle is Script {
    function run() external {
        // Load the deployer's private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Set the owner address as the desired deployer address or another address
        address ownerAddress = vm.addr(deployerPrivateKey);

        // Deploy the SimpleOracle contract with the owner address
        EdgePushOracle edgePushOracle = new EdgePushOracle(
            18, // decimals
            "test", // description
            ownerAddress // owner address
        );

        // Log the deployed contract address
        console.log("Deployed EdgePushOracle contract at", address(edgePushOracle));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
