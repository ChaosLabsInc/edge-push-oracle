// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/EdgePushOracle.sol";

contract EdgePushOracleTest is Test {
    EdgePushOracle public edgePushOracle;
    address public owner;
    address public oracle1;
    address public oracle2;

    uint256 private privateKey1;
    uint256 private privateKey2;

    function setUp() public {
        owner = address(this);

        // Assign private keys for oracles
        privateKey1 = 0xA11CE; // Some arbitrary private key
        privateKey2 = 0xB0B; // Another arbitrary private key

        // Corresponding addresses derived from the private keys
        oracle1 = vm.addr(privateKey1);
        oracle2 = vm.addr(privateKey2);

        edgePushOracle = new EdgePushOracle(8, "Test Oracle", owner);

        // Set block.timestamp to a non-zero value
        vm.warp(1 hours); // Set block.timestamp to 1 hour (3600 seconds)
    }

    function testAddTrustedOracle() public {
        assertTrue(!edgePushOracle.trustedOracles(oracle1), "Oracle1 should not be trusted yet");

        edgePushOracle.addTrustedOracle(oracle1);
        assertTrue(edgePushOracle.trustedOracles(oracle1), "Oracle1 should now be trusted");
    }

    function testRemoveTrustedOracle() public {
        edgePushOracle.addTrustedOracle(oracle1);
        assertTrue(edgePushOracle.trustedOracles(oracle1), "Oracle1 should be trusted");

        edgePushOracle.removeTrustedOracle(oracle1);
        assertTrue(!edgePushOracle.trustedOracles(oracle1), "Oracle1 should no longer be trusted");
    }

    function testPostUpdateWithMultipleOracles() public {
        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 expo = 2;
        uint256 obsTs = block.timestamp; // Now obsTs is 3600

        bytes memory report = abi.encode(price, reportRoundId, expo, obsTs);
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

        (uint80 roundId, int256 latestPrice,,,) = edgePushOracle.latestRoundData();
        assertEq(latestPrice, price, "The latest price should match the posted price");
        assertEq(roundId, 1, "Round ID should be 1");
    }

    function testPostUpdateWithInsufficientSignatures() public {
        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 expo = 2;
        uint256 obsTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, expo, obsTs);
        bytes32 reportHash = keccak256(report);

        // Simulate signature from only one oracle
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature1;

        vm.expectRevert("Not enough signatures");
        edgePushOracle.postUpdate(report, signatures);
    }

    function testPostUpdateWithFutureTimestamp() public {
        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 expo = 2;
        uint256 obsTs = block.timestamp + 10 minutes; // Future timestamp

        bytes memory report = abi.encode(price, reportRoundId, expo, obsTs);
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

        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        int256 price = 100;
        uint256 reportRoundId = 1;
        uint256 expo = 2;
        uint256 obsTs = block.timestamp - 1 hours - 1; // Old timestamp, obsTs = 3599

        bytes memory report = abi.encode(price, reportRoundId, expo, obsTs);
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

    function testLatestPriceRetrieval() public {
        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        int256 price = 200;
        uint256 reportRoundId = 1;
        uint256 expo = 2;
        uint256 obsTs = block.timestamp; // obsTs is 3600

        bytes memory report = abi.encode(price, reportRoundId, expo, obsTs);
        bytes32 reportHash = keccak256(report);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, reportHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, reportHash);

        bytes memory signature1 = abi.encodePacked(r1, s1, v1);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        edgePushOracle.postUpdate(report, signatures);

        assertEq(edgePushOracle.latestPrice(), price, "The latest price should be the posted price");
    }

    function testRoundDataRetrieval() public {
        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        int256 price = 150;
        uint256 reportRoundId = 2;
        uint256 expo = 3;
        uint256 obsTs = block.timestamp;

        bytes memory report = abi.encode(price, reportRoundId, expo, obsTs);
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
        assertEq(storedTimestamp, obsTs, "Stored timestamp should match");
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
        edgePushOracle.addTrustedOracle(oracle1);
        edgePushOracle.addTrustedOracle(oracle2);

        uint256 requiredSigs = edgePushOracle.requiredSignatures();
        assertEq(requiredSigs, 2, "Required signatures should be 2");

        // Add another oracle and check required signatures
        address oracle3 = vm.addr(0xC0DE);
        address oracle4 = vm.addr(0xDEAD);
        address oracle5 = vm.addr(0xBEEF);
        edgePushOracle.addTrustedOracle(oracle3);
        edgePushOracle.addTrustedOracle(oracle4);
        edgePushOracle.addTrustedOracle(oracle5);

        requiredSigs = edgePushOracle.requiredSignatures();
        assertEq(requiredSigs, 4, "Required signatures is wrong");
    }
}
