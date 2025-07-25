// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Types.sol";
import "./IPolyEscrow.sol";

enum ArbitrationType {
    REFUND,
    CANCEL,
    RELEASE
}

enum ArbitrationStatus {
    ACTIVE,
    REJECTED,
    ACCEPTED,
    EXECUTED,
    CANCELED
}

struct ArbitrationProposal {
    bytes32 id;
    bytes32 escrowId;
    ArbitrationType proposalType;
    ArbitrationStatus status;
    mapping(address => bool) votes;
    uint256 amount;
    uint8 votesFor;
    uint8 votesAgainst;
}

interface IArbitrationModule
{
    function proposeArbitration(IPolyEscrow polyEscrow, bytes32 escrowId, ArbitrationType proposalType, uint256 amount) external;

    function voteArbitration(IPolyEscrow polyEscrow, bytes32 arbitrationId, bool vote) external;

    function cancelArbitration(bytes32 arbitrationId) external;

    function executeArbitration(IPolyEscrow polyEscrow, bytes32 arbitrationId) external;
}
