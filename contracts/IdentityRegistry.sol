// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract IdentityRegistry {
    mapping(bytes32 => bool) public commitmentExists;
    bytes32[] public commitments;

    event IdentityRegistered(bytes32 indexed commitment, uint256 setSize);

    function registerIdentity(bytes32 commitment) external {
        require(!commitmentExists[commitment], "Commitment already registered");

        commitmentExists[commitment] = true;
        commitments.push(commitment);

        emit IdentityRegistered(commitment, commitments.length);
    }

    function getAnonymitySetSize() external view returns (uint256) {
        return commitments.length;
    }
}
