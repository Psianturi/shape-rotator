// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentRegistry
/// @notice Formalizes the 1-user-1-agent relationship on-chain.
///         Each user commitment maps to exactly one guardian agent.
///         Policy version hash is stored for auditability.
contract AgentRegistry {
    struct AgentRecord {
        bytes32 commitment;      // Anonymous user identity commitment
        address agentId;         // Guardian agent address
        bytes32 policyHash;      // keccak256 of active policy JSON
        uint64  createdAt;
        uint64  updatedAt;
        bool    active;
    }

    // commitment => AgentRecord
    mapping(bytes32 => AgentRecord) private _records;

    // agentId => commitment (reverse lookup)
    mapping(address => bytes32) public agentToCommitment;

    address public owner;

    event AgentCreated(bytes32 indexed commitment, address indexed agentId, bytes32 policyHash);
    event AgentUpdated(bytes32 indexed commitment, bytes32 newPolicyHash);
    event AgentRevoked(bytes32 indexed commitment, address indexed agentId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Register a new user-agent binding.
    function createAgent(bytes32 commitment, address agentId, bytes32 policyHash) external onlyOwner {
        require(_records[commitment].createdAt == 0, "Commitment already registered");
        require(agentToCommitment[agentId] == bytes32(0), "Agent already assigned");

        _records[commitment] = AgentRecord({
            commitment: commitment,
            agentId: agentId,
            policyHash: policyHash,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp),
            active: true
        });
        agentToCommitment[agentId] = commitment;

        emit AgentCreated(commitment, agentId, policyHash);
    }

    /// @notice Update the active policy hash for a user.
    function updatePolicy(bytes32 commitment, bytes32 newPolicyHash) external onlyOwner {
        require(_records[commitment].active, "Agent not active");
        _records[commitment].policyHash = newPolicyHash;
        _records[commitment].updatedAt = uint64(block.timestamp);
        emit AgentUpdated(commitment, newPolicyHash);
    }

    /// @notice Revoke a user-agent binding.
    function revokeAgent(bytes32 commitment) external onlyOwner {
        require(_records[commitment].active, "Agent not active");
        address agentId = _records[commitment].agentId;
        _records[commitment].active = false;
        _records[commitment].updatedAt = uint64(block.timestamp);
        delete agentToCommitment[agentId];
        emit AgentRevoked(commitment, agentId);
    }

    /// @notice Read agent record for a commitment.
    function getAgent(bytes32 commitment) external view returns (AgentRecord memory) {
        return _records[commitment];
    }

    /// @notice Check if a commitment has an active agent.
    function isActive(bytes32 commitment) external view returns (bool) {
        return _records[commitment].active;
    }
}
