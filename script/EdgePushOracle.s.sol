// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/EdgePushOracle.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEdgePushOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        EdgePushOracle implementation = new EdgePushOracle();

        // Encode the initialization call
        bytes memory data = abi.encodeWithSelector(
            EdgePushOracle.initialize.selector,
            8, // _decimals
            "Edge Push Oracle", // _description
            msg.sender // _owner
        );

        // Deploy the proxy, pointing it to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        // The proxy address is what you'll interact with
        console.log("Proxy deployed to:", address(proxy));

        vm.stopBroadcast();
    }
}
