// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/EdgePushOracle.sol";

contract EdgePushOracleTest is Test {
    EdgePushOracle public oracle;
    address public owner;

    function setUp() public {
        // Simulate a deployer's private key and wallet
        owner = address(this); // For this test, the test contract itself is the owner.

        // Deploys the contract with the initial setup
        oracle = new EdgePushOracle(18, "ETH/USD Price Feed", owner);
    }

    function testInitialValues() public view {
        assertEq(oracle.decimals(), 18);
        assertEq(oracle.description(), "ETH/USD Price Feed");
        assertEq(oracle.owner(), owner); // Verify that the owner is set correctly
    }

    function testPostUpdate() public {
        // Ensure only the owner can post an update
        oracle.postUpdate(3000);

        (int256 answer, uint256 timestamp, uint256 blockNumber) = oracle.getRoundData(1);

        assertEq(answer, 3000);
        assertGt(timestamp, 0);
        assertGt(blockNumber, 0);
        assertEq(oracle.latestAnswer(), 3000);
        assertEq(oracle.latestTimestamp(), timestamp);
    }

    function testSetDescription() public {
        // Ensure only the owner can update the description
        oracle.setDescription("BTC/USD Price Feed");
        assertEq(oracle.description(), "BTC/USD Price Feed");
    }

    function testSetDecimals() public {
        // Ensure only the owner can update the decimals
        oracle.setDecimals(8);
        assertEq(oracle.decimals(), 8);
    }

    function testOnlyOwnerCanUpdate() public {
        // Simulate a non-owner address
        address nonOwner = address(0x1337);
        vm.startPrank(nonOwner);

        // Try posting an update with a non-owner account (should fail)
        vm.expectRevert(); // More general revert check
        oracle.postUpdate(1000);

        // Try setting a new description with a non-owner account (should fail)
        vm.expectRevert(); // More general revert check
        oracle.setDescription("Non-owner Feed");

        // Try setting new decimals with a non-owner account (should fail)
        vm.expectRevert(); // More general revert check
        oracle.setDecimals(2);

        vm.stopPrank();
    }

    function testMultipleUpdates() public {
        oracle.postUpdate(1000);
        oracle.postUpdate(1500);
        oracle.postUpdate(2000);

        (, int256 answer,,,) = oracle.latestRoundData();
        assertEq(answer, 2000);
    }

    function testGetRoundDataInvalidRound() public {
        vm.expectRevert();
        oracle.getRoundData(999);
    }

    function testLatestRoundData() public {
        oracle.postUpdate(3000);
        (, int256 answer,,,) = oracle.latestRoundData();
        assertEq(answer, 3000);
    }
}
