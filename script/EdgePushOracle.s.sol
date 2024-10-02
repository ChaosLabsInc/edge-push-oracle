// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/EdgePushOracle.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// Contract for deploying EdgePushOracle with UUPS proxy pattern
contract DeployEdgePushOracle is Script {
    function run() external {
        // Load the deployer's private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory trustedOracles = new address[](0);

        // Start broadcasting transactions using the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Set the owner address as the address derived from the deployer's private key
        address ownerAddress = vm.addr(deployerPrivateKey);

        // Deploy the EdgePushOracle implementation contract
        EdgePushOracle edgePushOracleImplementation = new EdgePushOracle();

        // Log the deployed implementation contract address for verification
        console.log("Deployed EdgePushOracle implementation at", address(edgePushOracleImplementation));

        // Deploy the UUPS proxy pointing to the implementation
        // Note: Make sure the initialize parameters (8, "test", owner) are correct for your use case
        address proxy = Upgrades.deployUUPSProxy(
            "EdgePushOracle.sol", abi.encodeCall(EdgePushOracle.initialize, (8, "test", ownerAddress, trustedOracles))
        );

        // Log the deployed proxy contract address for verification
        console.log("Deployed EdgePushOracle proxy at", proxy);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
