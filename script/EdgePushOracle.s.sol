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

        address[] memory trustedOracles = new address[](5);
        trustedOracles[0] = 0xb42F25C68901b9291a488d68536f449538a7a182;
        trustedOracles[1] = 0xBb5e07e62Af4131e504a430EA608FE719E8db18A;
        trustedOracles[2] = 0xf1a2e6b10c24B0Db668e4D6654aD746Af776f27e;
        trustedOracles[3] = 0xe301279400AB18d9870065b4dc3fF0bf984EeE06;
        trustedOracles[4] = 0x152e901D6E71e95dAA31B13767a8589E20b99Aa3;

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
