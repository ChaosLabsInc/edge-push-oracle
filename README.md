# EdgePushOracle

EdgePushOracle is a smart contract designed to act as an oracle for price updates. It leverages OpenZeppelin's `Ownable` and `AccessControl` contracts to manage permissions and ownership.

## Features

- **Role-based Access Control**: Uses OpenZeppelin's `AccessControl` to manage oracle roles.
- **Price Updates**: Allows authorized oracles to post price updates.
- **Data Retrieval**: Provides functions to retrieve the latest price, timestamp, and block number.

## Contract Overview

The main contract is `EdgePushOracle`, which includes the following key components:

- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Admin role for managing other roles.
  - `ORACLE_ROLE`: Role for accounts that can post price updates.

- **Events**:
  - `PriceUpdated`: Emitted when a new price is posted.

- **Functions**:
  - `postUpdate(int256 answer)`: Allows an oracle to post a new price update.
  - `getRoundData(uint256 round)`: Retrieves data for a specific round.
  - `latestAnswer()`: Retrieves the latest price.
  - `latestTimestamp()`: Retrieves the timestamp of the latest price.
  - `setDescription(string memory _description)`: Allows the owner to set the description.
  - `setDecimals(uint8 _decimals)`: Allows the owner to set the decimals.
  - `grantOracleRole(address account)`: Allows the owner to grant the oracle role to an account.
  - `revokeOracleRole(address account)`: Allows the owner to revoke the oracle role from an account.

## Deployment

To deploy the `EdgePushOracle` contract, follow these steps:

### Prerequisites

- Ensure you have [Foundry](https://book.getfoundry.sh/) installed. If not, you can install it using the following command:
  ```shell
  curl -L https://foundry.paradigm.xyz | bash
  ```

### Build

1. Clone the repository:
   ```shell
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Install dependencies:
   ```shell
   forge install
   ```

3. Build the project:
   ```shell
   forge build
   ```

### Deploy

1. Create a deployment script (e.g., `script/Deploy.s.sol`):
   ```solidity
   // SPDX-License-Identifier: MIT
   pragma solidity ^0.8.0;

   import "forge-std/Script.sol";
   import "../src/EdgePushOracle.sol";

   contract DeployScript is Script {
       function run() external {
           uint8 decimals = 18;
           string memory description = "Edge Push Oracle";
           address owner = msg.sender;

           vm.startBroadcast();
           new EdgePushOracle(decimals, description, owner);
           vm.stopBroadcast();
       }
   }
   ```

2. Deploy the contract using Foundry:
   ```shell
   forge script script/Deploy.s.sol:DeployScript --rpc-url <your_rpc_url> --private-key <your_private_key>
   ```

### Testing

To run tests, use the following command: 
```shell
forge test
```

### Formatting

To format the code, use:
```shell
forge fmt
```

### Additional Commands

For more commands and usage, refer to the [Foundry documentation](https://book.getfoundry.sh/).

## License

This project is licensed under the MIT License.