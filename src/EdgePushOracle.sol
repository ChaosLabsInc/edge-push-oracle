// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title EdgePushOracle
 * @dev A decentralized oracle contract that allows trusted oracles to push price updates
 * with multi-signature verification.
 */
contract EdgePushOracle is Ownable {
    // ============ Structs ============

    struct RoundData {
        int256 price; // Price
        uint256 reportRoundId; // Report Round Id
        uint256 observedTs; // Observation Timestamp
        uint256 blockNumber; // Block Number
        uint256 postedTs; // Posted Timestamp
        uint256 numSignatures; // Number of valid signatures for this round
    }

    // ============ State Variables ============

    uint80 public latestRound;
    uint8 public decimals;
    string public description;
    mapping(uint80 => RoundData) public rounds;

    // Mapping of trusted oracle addresses
    mapping(address => bool) public trustedOracles;
    address[] public oracles;

    // ============ Events ============

    event OracleAdded(address indexed oracle);
    event OracleRemoved(address indexed oracle);
    event NewTransmission(
        uint80 indexed roundId, int256 price, uint256 reportRoundId, uint256 timestamp, address transmitter
    );

    // ============ Constructor ============

    constructor(uint8 _decimals, string memory _description, address _owner) Ownable(_owner) {
        decimals = _decimals;
        description = _description;
    }

    // ============ Oracle Management Functions ============

    /**
     * @notice Owner can add a trusted oracle
     * @param oracle Address of the oracle to be added
     */
    function addTrustedOracle(address oracle) external onlyOwner {
        require(!trustedOracles[oracle], "Oracle already trusted");
        trustedOracles[oracle] = true;
        oracles.push(oracle);
        emit OracleAdded(oracle);
    }

    /**
     * @notice Owner can remove a trusted oracle
     * @param oracle Address of the oracle to be removed
     */
    function removeTrustedOracle(address oracle) external onlyOwner {
        require(trustedOracles[oracle], "Oracle not found");
        trustedOracles[oracle] = false;
        // Remove from oracles array
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i] == oracle) {
                oracles[i] = oracles[oracles.length - 1];
                oracles.pop();
                break;
            }
        }
        emit OracleRemoved(oracle);
    }

    // ============ Update Posting Function ============

    /**
     * @notice Anyone can submit a report signed by multiple trusted oracles
     * @param report Encoded report data
     * @param signatures Array of signatures from trusted oracles
     */
    function postUpdate(bytes memory report, bytes[] memory signatures) public {
        // Decode report
        (int256 price, uint256 reportRoundId, uint256 obsTs) = abi.decode(report, (int256, uint256, uint256));

        // Timestamp checks
        require(obsTs > rounds[latestRound].observedTs, "Report timestamp is not newer");
        require(obsTs <= block.timestamp + 5 minutes, "Report timestamp too far in the future");

        uint256 minAllowedTimestamp = block.timestamp > 1 hours ? block.timestamp - 1 hours : 0;
        require(obsTs >= minAllowedTimestamp, "Report timestamp too old");

        // Signature verification
        bytes32 reportHash = keccak256(report);
        uint256 numSignatures = signatures.length;
        uint256 validSignatures = 0;
        address[] memory signers = new address[](numSignatures);

        for (uint256 i = 0; i < numSignatures; i++) {
            address signer = recoverSignerAddress(reportHash, signatures[i]);
            require(trustedOracles[signer], "Signer is not a trusted oracle");

            // Check for duplicates
            bool isDuplicate = false;
            for (uint256 j = 0; j < validSignatures; j++) {
                if (signers[j] == signer) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                signers[validSignatures] = signer;
                validSignatures++;
            }
        }

        //require(validSignatures >= requiredSignatures(), "Not enough signatures");

        // Update state
        require(latestRound < type(uint80).max, "Latest round exceeds uint80 limit");
        latestRound++;
        rounds[latestRound] = RoundData({
            price: price,
            reportRoundId: reportRoundId,
            observedTs: obsTs,
            blockNumber: block.number,
            postedTs: block.timestamp,
            numSignatures: validSignatures
        });

        // Emit event with the transmission details
        emit NewTransmission(latestRound, price, reportRoundId, obsTs, msg.sender);
    }

    // ============ Utility Functions ============

    /**
     * @notice Returns the number of required signatures (e.g., majority)
     * @return The number of required signatures
     */
    function requiredSignatures() public view returns (uint256) {
        uint256 totalOracles = oracles.length;
        uint256 threshold = (totalOracles * 2) / 3 + 1; // More than 66%
        if (threshold > totalOracles) {
            threshold = totalOracles;
        }
        if (threshold == 0) {
            threshold = 1; // At least one signature required
        }
        return threshold;
    }

    // ============ Data Retrieval Functions ============

    /**
     * @notice Retrieve round data for a specific round
     * @param round The round number to retrieve data for
     * @return price The price for the specified round
     * @return reportRoundId The report round ID
     * @return timestamp The timestamp of the observation
     * @return blockNumber The block number when the round was posted
     */
    function getRoundData(uint80 round)
        public
        view
        returns (int256 price, uint256 reportRoundId, uint256 timestamp, uint256 blockNumber)
    {
        require(round > 0 && round <= latestRound, "Round is not yet available");
        RoundData storage data = rounds[round];
        return (data.price, data.reportRoundId, data.observedTs, data.blockNumber);
    }

    /**
     * @notice Retrieve the latest price
     * @return price The latest reported price
     */
    function latestPrice() public view returns (int256 price) {
        return rounds[latestRound].price;
    }

    /**
     * @notice Returns details of the latest successful update round
     * @return roundId The number of the latest round
     * @return answer The latest reported value
     * @return startedAt Block timestamp when the latest successful round started
     * @return updatedAt Block timestamp of the latest successful round
     * @return answeredInRound The number of the latest round
     */
    function latestRoundData()
        public
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = uint80(latestRound);
        answer = latestAnswer();
        RoundData storage data = rounds[latestRound];
        startedAt = data.observedTs;
        updatedAt = data.postedTs;
        answeredInRound = roundId;
    }

    /**
     * @notice Retrieve the timestamp of the latest round
     * @return timestamp The timestamp of the latest round
     */
    function latestTimestamp() public view returns (uint256 timestamp) {
        return rounds[latestRound].postedTs;
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the description of the oracle
     * @param _description The new description
     */
    function setDescription(string memory _description) public onlyOwner {
        description = _description;
    }

    /**
     * @notice Set the number of decimals for the answer values
     * @param _decimals The new number of decimals
     */
    function setDecimals(uint8 _decimals) public onlyOwner {
        decimals = _decimals;
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper function that generates the Ethereum-style message hash
     * @param _data The data to hash
     * @return The keccak256 hash of the data
     */
    function getMessageHash(bytes memory _data) external pure returns (bytes32) {
        return keccak256(_data);
    }

    /**
     * @notice Old Chainlink function for getting the latest successfully reported value
     * @return latestAnswer The latest successfully reported value
     */
    function latestAnswer() public view virtual returns (int256) {
        return rounds[latestRound].price;
    }

    function recoverSignerAddress(bytes32 _messageHash, bytes memory _signature) public pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");

        // Extract the signature components: v, r, and s
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Signatures are in the format {r}{s}{v}, we extract them from the passed signature
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }

        // Constants for chain IDs greater than 36 can have v appended with 27 or 28, so we normalize it
        if (v < 27) {
            v += 27;
        }

        // Ensure it's a valid value for v (27 or 28 are the only valid recovery IDs in Ethereum)
        require(v == 27 || v == 28, "Invalid signature v value");

        // ecrecover returns the public key in Ethereum style (the address)
        return ecrecover(_messageHash, v, r, s);
    }
}
