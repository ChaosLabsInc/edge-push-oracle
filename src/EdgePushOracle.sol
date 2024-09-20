// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract EdgePushOracle is Ownable, AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct RoundData {
        int256 answer;
        uint256 timestamp;
        uint256 blockNumber;
    }

    uint80 public latestRound;
    uint8 public decimals;
    string public description;
    mapping(uint80 => RoundData) public rounds;

    event PriceUpdated(uint80 indexed round, int256 answer, uint256 timestamp, uint256 blockNumber);

    /**
     * @dev Constructor allows the owner to set the initial global decimals value and description.
     * @param _decimals The number of decimals for the answer values
     * @param _description A short description or title for the feed
     * @param _owner The address of the initial owner of the contract
     */
    constructor(uint8 _decimals, string memory _description, address _owner) Ownable(_owner) {
        decimals = _decimals;
        description = _description;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ORACLE_ROLE, _owner);
    }

    function postUpdate(int256 answer) public onlyRole(ORACLE_ROLE) {
        latestRound++;
        rounds[latestRound] = RoundData({answer: answer, timestamp: block.timestamp, blockNumber: block.number});

        emit PriceUpdated(latestRound, answer, block.timestamp, block.number);
    }

    function getRoundData(uint80 round) public view returns (int256 answer, uint256 timestamp, uint256 blockNumber) {
        require(round <= latestRound, "Round is not yet available");
        RoundData storage data = rounds[round];
        return (data.answer, data.timestamp, data.blockNumber);
    }

    function latestAnswer() public view returns (int256 answer) {
        return rounds[latestRound].answer;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            latestRound,
            rounds[latestRound].answer,
            rounds[latestRound].timestamp,
            rounds[latestRound].timestamp,
            latestRound
        );
    }

    function latestTimestamp() public view returns (uint256 timestamp) {
        return rounds[latestRound].timestamp;
    }

    function setDescription(string memory _description) public onlyOwner {
        description = _description;
    }

    function setDecimals(uint8 _decimals) public onlyOwner {
        decimals = _decimals;
    }

    function grantOracleRole(address account) public onlyOwner {
        grantRole(ORACLE_ROLE, account);
    }

    function revokeOracleRole(address account) public onlyOwner {
        revokeRole(ORACLE_ROLE, account);
    }
}
