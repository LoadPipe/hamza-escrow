// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

enum EscrowStatus { 
    Pending, 
    Active, 
    Completed, 
    Arbitration 
}

enum ProposalType {
    Refund,
    Release
}

enum ProposalStatus {
    Pending,
    Passed,
    Cancelled,
    Expired
}

struct Escrow {
    bytes32 id; // Unique identifier for the escrow
    address payer; // The address of the payer
    address receiver; // The address of the receiver
    address[] arbiters; // The addresses of the arbiters
    uint8 arbitersRequired; // The number of arbiters consent required to release or refund the escrow in absence of payer consent
    uint256 amount; // The total amount of the escrow
    address currency; //The currency addres, 0x0 for native
    uint256 amountRefunded; // The amount refunded so far
    uint256 amountReleased; // The amount released so far
    uint256 amountPaid; // The amount paid so far
    uint256 timestamp; // The timestamp when the escrow was created
    uint256 startTime; // The timestamp when the escrow period begins
    uint256 endTime; //The timestamp when the escrow period ends
    EscrowStatus status; // 0 = pending, 1 = active, 2 = completed, 3=arbitration
    bool fullyPaid; // Indicates if the escrow is fully paid
    bool payerReleased; 
    bool receiverReleased;
    bool released;
}

struct EscrowArbitrationProposal {
    bytes32 escrowId; // The ID of the escrow being proposed for arbitration
    address proposer; // The address of the proposer
    string reason; // The reason for the arbitration proposal
    uint256 timestamp; // The timestamp when the proposal was made
    ProposalType proposalType; // 1 = refund, 2 = release
    uint256 amount;
    uint8[] votes;
    ProposalStatus status;
}


/* Encapsulates information about an incoming escrow payment
*/
struct PaymentInput
{
    bytes32 escrowId;
    address currency; //token address, or 0x0 for native 
    uint256 amount;
}
