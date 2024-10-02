// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @title EdgePushOracle
 * @dev A decentralized oracle contract that allows trusted oracles to push price updates
 * with multi-signature verification. Upgradable using UUPS proxy pattern.
 */
contract EdgePushOracle is OwnableUpgradeable, UUPSUpgradeable {
    // ============ Structs ============

    struct RoundData {
        int256 price; // Price of the asset
        uint256 reportRoundId; // ID of the report round
        uint256 observedTs; // Timestamp when the observation was made
        uint256 blockNumber; // Block number of the transaction
        uint256 postedTs; // Timestamp when the data was posted
        uint8 numSignatures; // Count of valid signatures for this round
    }

    // ============ State Variables ============

    uint8 public decimals; // Number of decimal places for price
    string public description; // Description of the oracle
    uint80 internal _latestRound; // Tracks the latest round number, initialized to 0
    mapping(uint80 => RoundData) public rounds; // Mapping of round number to RoundData

    mapping(address => bool) public trustedOracles; // Mapping of trusted oracle addresses
    address[] public oracles; // List of all trusted oracles

    // ============ Events ============

    event OracleAdded(address indexed oracle); // Event emitted when an oracle is added
    event OracleRemoved(address indexed oracle); // Event emitted when an oracle is removed
    event NewPriceUpdate(
        uint80 indexed roundId,
        int256 price,
        uint256 reportRoundId,
        uint256 timestamp,
        address transmitter,
        uint256 numSignatures
    ); // Event emitted for new price update

    // ============ Initializer ============

    /**
     * @notice Initializes the contract instead of using a constructor
     * @param _decimals Number of decimal places for price
     * @param _description Description of the oracle
     * @param _owner Address of the contract owner
     * @param _oracles Array of oracle addresses to be added
     */
    function initialize(uint8 _decimals, string memory _description, address _owner, address[] memory _oracles)
        public
        initializer
    {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        decimals = _decimals; // Set the number of decimals
        description = _description; // Set the description
        _latestRound = 0;

        // Add initial oracles
        for (uint256 i = 0; i < _oracles.length; i++) {
            address oracle = _oracles[i];
            require(!trustedOracles[oracle], "Oracle already trusted"); // Check if oracle is already trusted
            trustedOracles[oracle] = true; // Mark oracle as trusted
            oracles.push(oracle); // Add oracle to the list
        }

        //_disableInitializers();
    }

    // ============ Upgrade Authorization ============

    /**
     * @dev Function that authorizes an upgrade to a new implementation.
     * Only the owner can upgrade the contract.
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ Oracle Management Functions ============

    /**
     * @notice Owner can add a trusted oracle
     * @param oracle Address of the oracle to be added
     */
    function addOracle(address oracle) external onlyOwner {
        require(!trustedOracles[oracle], "Oracle already trusted"); // Check if oracle is already trusted
        trustedOracles[oracle] = true; // Mark oracle as trusted
        oracles.push(oracle); // Add oracle to the list
        emit OracleAdded(oracle); // Emit event
    }

    /**
     * @notice Owner can remove a trusted oracle
     * @param oracle Address of the oracle to be removed
     */
    function removeOracle(address oracle) external onlyOwner {
        require(trustedOracles[oracle], "Oracle not found"); // Check if oracle is trusted
        trustedOracles[oracle] = false; // Mark oracle as untrusted
        // Remove from oracles array
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i] == oracle) {
                oracles[i] = oracles[oracles.length - 1]; // Replace with last element
                oracles.pop(); // Remove last element
                break; // Exit loop
            }
        }
        emit OracleRemoved(oracle); // Emit event
    }

    // ============ Update Posting Function ============

    /**
     * @notice Anyone can submit a report signed by multiple trusted oracles
     * @param report Encoded report data (int256 price, uint256 reportRoundId, uint256 obsTs)
     * @param signatures Array of signatures from trusted oracles
     */
    function postUpdate(bytes memory report, bytes[] memory signatures) external {
        // Decode report
        (int256 price, uint256 reportRoundId, uint256 observationTs) = abi.decode(report, (int256, uint256, uint256));

        // Timestamp checks
        require(observationTs > rounds[_latestRound].observedTs, "Report timestamp is not newer"); // Ensure new timestamp
        require(observationTs <= block.timestamp + 5 minutes, "Report timestamp too far in the future"); // Check future timestamp

        uint256 minAllowedTimestamp = block.timestamp > 1 hours ? block.timestamp - 1 hours : 0; // Calculate minimum allowed timestamp
        require(observationTs >= minAllowedTimestamp, "Report timestamp too old"); // Check old timestamp

        // Signature verification
        bytes32 reportHash = keccak256(report); // Hash the report
        uint256 numSignatures = signatures.length; // Get number of signatures
        uint256 validSignatures = 0; // Initialize valid signatures count
        address[] memory signers = new address[](numSignatures); // Array to store signers

        for (uint256 i = 0; i < numSignatures; i++) {
            address signer = recoverSignerAddress(reportHash, signatures[i]); // Recover signer address
            require(trustedOracles[signer], "Signer is not a trusted oracle"); // Check if signer is trusted

            // Check for duplicates
            bool isDuplicate = false; // Flag for duplicate signers
            for (uint256 j = 0; j < validSignatures; j++) {
                if (signers[j] == signer) {
                    isDuplicate = true; // Mark as duplicate
                    break; // Exit loop
                }
            }
            if (!isDuplicate) {
                signers[validSignatures] = signer; // Add signer to list
                validSignatures++; // Increment valid signatures count
            }
        }

        require(validSignatures >= requiredSignatures(), "Not enough signatures"); // Ensure enough valid signatures

        require(_latestRound < type(uint80).max, "Latest round exceeds uint80 limit"); // Check round limit
        _latestRound++; // Increment latest round
        rounds[_latestRound] = RoundData({
            price: price,
            reportRoundId: reportRoundId,
            observedTs: observationTs,
            blockNumber: block.number,
            postedTs: block.timestamp,
            numSignatures: uint8(validSignatures) // Store valid signatures as uint8
        }); // Store round data

        emit NewPriceUpdate(_latestRound, price, reportRoundId, observationTs, msg.sender, validSignatures); // Emit new price update event
    }

    // ============ Utility Functions ============

    /**
     * @notice Returns the number of required signatures (e.g., majority)
     * @return The number of required signatures
     */
    function requiredSignatures() public view returns (uint256) {
        uint256 totalOracles = oracles.length; // Get total number of oracles
        uint256 threshold = (totalOracles * 2) / 3; // Calculate threshold for majority
        return threshold > 0 ? threshold : 1; // Return required signatures
    }

    // ============ Data Retrieval Functions ============

    function latestRound() external view returns (uint256) {
        return uint256(_latestRound); // Return the latest round number
    }

    function getAnswer(uint256 roundId) external view returns (int256) {
        require(roundId > 0 && roundId <= _latestRound, "Round is not yet available"); // Check round availability
        return rounds[uint80(roundId)].price; // Return the price for the specified round
    }

    function getTimestamp(uint256 roundId) external view returns (uint256) {
        require(roundId > 0 && roundId <= _latestRound, "Round is not yet available"); // Check round availability
        return rounds[uint80(roundId)].postedTs; // Return the timestamp for the specified round
    }

    /**
     * @notice Retrieve round data for a specific round
     * @param round The round number to retrieve data for
     * @return price The price for the specified round
     * @return reportRoundId The report round ID
     * @return timestamp The timestamp of the observation
     * @return blockNumber The block number when the round was posted
     */
    function getRoundData(uint80 round)
        external
        view
        returns (int256 price, uint256 reportRoundId, uint256 timestamp, uint256 blockNumber)
    {
        require(round > 0 && round <= _latestRound, "Round is not yet available"); // Check round availability
        RoundData storage data = rounds[round]; // Get round data
        return (data.price, data.reportRoundId, data.observedTs, data.blockNumber); // Return round data
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
        external
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = uint80(_latestRound); // Get latest round ID
        answer = latestAnswer(); // Get latest answer
        RoundData storage data = rounds[_latestRound]; // Get latest round data
        startedAt = data.observedTs; // Get start timestamp
        updatedAt = data.postedTs; // Get update timestamp
        answeredInRound = roundId; // Set answered in round
    }

    /**
     * @notice Retrieve the timestamp of the latest round
     * @return timestamp The timestamp of the latest round
     */
    function latestTimestamp() external view returns (uint256 timestamp) {
        return rounds[_latestRound].postedTs; // Return latest round timestamp
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the description of the oracle
     * @param _description The new description
     */
    function setDescription(string memory _description) external onlyOwner {
        description = _description; // Update description
    }

    /**
     * @notice Set the number of decimals for the answer values
     * @param _decimals The new number of decimals
     */
    function setDecimals(uint8 _decimals) external onlyOwner {
        decimals = _decimals; // Update decimals
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper function that generates the Ethereum-style message hash
     * @param _data The data to hash
     * @return The keccak256 hash of the data
     */
    function getMessageHash(bytes memory _data) external pure returns (bytes32) {
        return keccak256(_data); // Return hash of data
    }

    /**
     * @notice Old Chainlink function for getting the latest successfully reported value
     * @return latestAnswer The latest successfully reported value
     */
    function latestAnswer() public view virtual returns (int256) {
        return rounds[_latestRound].price; // Return latest answer
    }

    /**
     * @notice Recovers the signer's address from a message hash and its signature
     * @param _messageHash The hash of the message that was signed
     * @param _signature The signature of the message (65 bytes: r, s, v)
     * @return The address of the signer
     */
    function recoverSignerAddress(bytes32 _messageHash, bytes memory _signature) private pure returns (address) {
        require(_signature.length == 65, "Invalid signature length"); // Check signature length

        // Extract the signature components: v, r, and s
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // First 32 bytes after length prefix
            r := mload(add(_signature, 0x20))
            // Second 32 bytes
            s := mload(add(_signature, 0x40))
            // Final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_signature, 0x60)))
        }

        // Adjust v value if necessary
        if (v < 27) {
            v += 27; // Adjust v to be 27 or 28
        }
        require(v == 27 || v == 28, "Invalid signature 'v' value"); // Check v value

        // Enforce lower half order for s to prevent malleable signatures
        uint256 sInt = uint256(s);
        require(
            sInt <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Invalid signature 's' value"
        );

        // Recover the address
        address recovered = ecrecover(_messageHash, v, r, s);
        require(recovered != address(0), "Invalid signature");

        return recovered;
    }
}
