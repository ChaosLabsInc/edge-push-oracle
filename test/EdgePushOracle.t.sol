// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/EdgePushOracle.sol";

contract EdgePushOracleTest is Test {
    EdgePushOracle public edgePushOracle;
    address public owner;
    address public oracle1;
    address public oracle2;
    address public oracle3;
    uint256 private privateKey1;
    uint256 private privateKey2;
    uint256 private privateKey3;

    function setUp() public {
        owner = address(this);

        // Assign private keys for oracles
        privateKey1 = 0xA11CE; // Some arbitrary private key
        privateKey2 = 0xB0B; // Another arbitrary private key
        privateKey3 = 0xC0DE; // Another arbitrary private key
        // Corresponding addresses derived from the private keys
        oracle1 = vm.addr(privateKey1);
        oracle2 = vm.addr(privateKey2);
        oracle3 = vm.addr(privateKey3);

        address[] memory trustedOracles = new address[](0);

        address proxy = Upgrades.deployUUPSProxy(
            "EdgePushOracle.sol", abi.encodeCall(EdgePushOracle.initialize, (8, "test", owner, trustedOracles))
        );

        // Assign edgePushOracle to point to the deployed proxy
        edgePushOracle = EdgePushOracle(proxy);

        // Set block.timestamp to a non-zero value
        vm.warp(1 hours); // Set block.timestamp to 1 hour (3600 seconds)
    }

    function testAddTrustedOracle() public {
        assertTrue(!edgePushOracle.trustedOracles(oracle1), "Oracle1 should not be trusted yet");

        edgePushOracle.addOracle(oracle1);
        assertTrue(edgePushOracle.trustedOracles(oracle1), "Oracle1 should now be trusted");
    }

    function testRemoveTrustedOracle() public {
        edgePushOracle.addOracle(oracle1);
        assertTrue(edgePushOracle.trustedOracles(oracle1), "Oracle1 should be trusted");

        edgePushOracle.removeOracle(oracle1);
        assertTrue(!edgePushOracle.trustedOracles(oracle1), "Oracle1 should no longer be trusted");
    }

    function testPostUpdateWithMultipleOracles() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        // Simulate signatures from oracles using their private keys
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        edgePushOracle.postUpdate(report, signatures);

        (uint80 roundId, int256 latestAnswer,,,) = edgePushOracle.latestRoundData();
        assertEq(latestAnswer, price, "The latest price should match the posted price");
        assertEq(roundId, 1, "Round ID should be 1");
    }

    function testPostUpdateWithInsufficientSignatures() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);
        edgePushOracle.addOracle(oracle3);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 obsTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, obsTs);
        bytes32 reportHash = keccak256(report);

        // Simulate signature from only one oracle
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature1;

        vm.expectRevert();
        edgePushOracle.postUpdate(report, signatures);
    }

    function testPostUpdateWithFutureTimestamp() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp + 10 minutes; // Future timestamp

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        vm.expectRevert("Report timestamp too far in the future");
        edgePushOracle.postUpdate(report, signatures);
    }

    function testPostUpdateWithOldTimestamp() public {
        // Set block.timestamp to a value greater than 1 hour to avoid underflow
        vm.warp(2 hours); // block.timestamp = 7200

        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;

        uint256 observationTs = block.timestamp - 1 hours - 1; // Old timestamp, observationTs = 3599

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        vm.expectRevert("Report timestamp too old");
        edgePushOracle.postUpdate(report, signatures);
    }

    function testRoundDataRetrieval() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 150;
        uint256 reportRoundId = 2;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        edgePushOracle.postUpdate(report, signatures);

        // Retrieve round data
        (int256 storedPrice, uint256 storedReportRoundId, uint256 storedTimestamp, uint256 storedBlockNumber) =
            edgePushOracle.getRoundData(1);

        assertEq(storedPrice, price, "Stored price should match the posted price");
        assertEq(storedReportRoundId, reportRoundId, "Stored reportRoundId should match");
        assertEq(storedTimestamp, observationTs, "Stored timestamp should match");
        assertEq(storedBlockNumber, block.number, "Stored blockNumber should match");
    }

    function testSetDescription() public {
        string memory newDescription = "New Oracle Description";
        edgePushOracle.setDescription(newDescription);
        assertEq(edgePushOracle.description(), newDescription, "Description should be updated");
    }

    function testSetDecimals() public {
        uint8 newDecimals = 10;
        edgePushOracle.setDecimals(newDecimals);
        assertEq(edgePushOracle.decimals(), newDecimals, "Decimals should be updated");
    }

    function testRequiredSignatures() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        uint256 requiredSigs = edgePushOracle.requiredSignatures();
        assertEq(requiredSigs, 1, "Required signatures should be 1");

        // Add another oracle and check required signatures
        address oracle4 = vm.addr(0xDEAD);
        address oracle5 = vm.addr(0xBEEF);
        edgePushOracle.addOracle(oracle3);
        edgePushOracle.addOracle(oracle4);
        edgePushOracle.addOracle(oracle5);

        requiredSigs = edgePushOracle.requiredSignatures();
        assertEq(requiredSigs, 3, "Required signatures is wrong");
    }

    function testPostUpdateWithProvidedData() public {
        address oracle = 0x9bf985216822e1522c02b100D6b0224338c33b6B;
        edgePushOracle.addOracle(oracle);
        vm.warp(1727186883);

        bytes memory report =
            hex"0000000000000000000000000000000000000000000000000000000005f5b41500000000000000000000000000000000000000000000000000000000015536110000000000000000000000000000000000000000000000000000000066f2c7c4";

        bytes[] memory signatures = new bytes[](1);
        signatures[0] =
            hex"903f94c7f5cf0057788cdd524fa2d1f21780e025cadb85f0038689741a286e842fc5082bc4972add8b7df4f259d79d37591bf415760711089a75949e9880c17001";

        //(int256 price, uint256 reportRoundId, uint256 observationTs) = abi.decode(report, (int256, uint256, uint256));
        //assertEq(block.timestamp, obsTs, "Observed timestamp should match");

        edgePushOracle.postUpdate(report, signatures);

        (uint80 roundId, int256 latestAnswer,,,) = edgePushOracle.latestRoundData();
        assertEq(latestAnswer, 99988501, "The latest price should match the posted price");
        assertEq(roundId, 1, "Round ID should match the posted round ID");
    }

    function testAddDuplicateOracle() public {
        edgePushOracle.addOracle(oracle1);
        vm.expectRevert("Oracle already trusted"); // Expect revert for duplicate addition
        edgePushOracle.addOracle(oracle1);
    }

    function testRemoveNonExistentOracle() public {
        vm.expectRevert("Oracle not found"); // Expect revert for removing non-existent oracle
        edgePushOracle.removeOracle(oracle1);
    }

    function testPostUpdateWithInvalidSignatures() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        // Simulate invalid signature
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        bytes memory invalidSignature = abi.encodePacked(r1, s1, v1 + 1); // Alter v to make it invalid

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = invalidSignature;

        vm.expectRevert(); // Expect revert due to invalid signature
        edgePushOracle.postUpdate(report, signatures);
    }

    function testPostUpdateWithNoOracles() public {
        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);

        bytes[] memory signatures = new bytes[](0); // No signatures

        vm.expectRevert(); // Expect revert due to no trusted oracles
        edgePushOracle.postUpdate(report, signatures);
    }

    function testPostUpdateWithAllOraclesRemoved() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.removeOracle(oracle1); // Remove the only oracle

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);

        bytes[] memory signatures = new bytes[](0); // No signatures

        vm.expectRevert(); // Expect revert due to no trusted oracles
        edgePushOracle.postUpdate(report, signatures);
    }

    function testGetRoundDataForNonExistentRound() public {
        vm.expectRevert("Round is not yet available"); // Expect revert for non-existent round
        edgePushOracle.getRoundData(1); // Attempt to get data for round 1 which doesn't exist
    }

    function testSetDescriptionToEmptyString() public {
        edgePushOracle.setDescription(""); // Set description to empty string
        assertEq(edgePushOracle.description(), "", "Description should be updated to empty string");
    }

    function testSetDecimalsToZero() public {
        edgePushOracle.setDecimals(0); // Set decimals to zero
        assertEq(edgePushOracle.decimals(), 0, "Decimals should be updated to zero");
    }

    function testRequiredSignaturesEdgeCase() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);
        edgePushOracle.addOracle(oracle3);

        uint256 requiredSigs = edgePushOracle.requiredSignatures();
        assertEq(requiredSigs, 2, "Required signatures should be 2 with 3 oracles");

        // Add another oracle and check required signatures
        address oracle4 = vm.addr(0xDEAD);
        address oracle5 = vm.addr(0xBEEF);
        edgePushOracle.addOracle(oracle4);
        edgePushOracle.addOracle(oracle5);

        requiredSigs = edgePushOracle.requiredSignatures();
        assertEq(requiredSigs, 3, "Required signatures should be 3 with 5 oracles");
    }

    function testLatestRound() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        edgePushOracle.postUpdate(report, signatures);

        assertEq(edgePushOracle.latestRound(), 1, "Latest round should be 1");
    }

    function testGetAnswer() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        edgePushOracle.postUpdate(report, signatures);

        assertEq(edgePushOracle.getAnswer(1), price, "The answer for round 1 should be the posted price");
    }

    function testGetTimestamp() public {
        edgePushOracle.addOracle(oracle1);
        edgePushOracle.addOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 observationTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, observationTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        edgePushOracle.postUpdate(report, signatures);

        assertEq(
            edgePushOracle.getTimestamp(1), block.timestamp, "The timestamp for round 1 should be the block timestamp"
        );
    }

    function testTransferOwnership() public {
        // Verify the initial owner is the test contract (address(this))
        assertEq(edgePushOracle.owner(), owner, "Initial owner should be the deployer (test contract)");

        // Create a new address to transfer ownership to
        address newOwner = vm.addr(0xABCD);

        // Transfer ownership to newOwner
        edgePushOracle.transferOwnership(newOwner);

        // Verify that the owner has been updated
        assertEq(edgePushOracle.owner(), newOwner, "Owner should be updated to newOwner");

        // Try to call an onlyOwner function from the old owner (should fail)
        vm.expectRevert();
        edgePushOracle.setDescription("Should fail");

        // Switch to newOwner and update the description
        vm.prank(newOwner);
        edgePushOracle.setDescription("Updated by new owner");

        // Verify that the description was updated
        assertEq(edgePushOracle.description(), "Updated by new owner", "Description should be updated by new owner");
    }
}
