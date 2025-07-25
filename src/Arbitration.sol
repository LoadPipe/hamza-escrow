// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Types.sol";
import "./interfaces/IPolyEscrow.sol";

enum ArbitrationType {
    REFUND,
    CANCEL,
    RELEASE
}

enum ArbitrationStatus {
    LIVE,
    REJECTED,
    ACCEPTED,
    EXECUTED
}

struct ArbitrationProposal {
    bytes32 id;
    bytes32 escrowId;
    ArbitrationType proposalType;
    ArbitrationStatus status;
    mapping(address => bool) votes;
    uint8 votesFor;
    uint8 votesAgainst;
}

/**
 * @title Arbitration
 */
contract Arbitration
{
    IPolyEscrow public polyEscrow;
    mapping(bytes32 => ArbitrationProposal) private proposals;
    uint8 public proposalCount;

    //EVENTS 
    event ArbitrationProposed (
        bytes32 indexed id,
        bytes32 indexed escrowId,
        address proposer
    );

    event VoteRecorded (
        bytes32 indexed id,
        bytes32 indexed escrowId,
        address voter
    );

    event ProposalExecuted (
        bytes32 indexed id,
        bytes32 indexed escrowId,
        address executor
    );

    constructor(IPolyEscrow _polyEscrow) {
        polyEscrow = _polyEscrow;
    }

    function proposeArbitration(bytes32 escrowId, ArbitrationType proposalType) public virtual {

        /*
        WHO can propose arbitration? 
        1. the payer 
        2. the receiver 
        3. arbiters? 
        */
        require (_canProposeArbitration(escrowId, msg.sender), "Unauthorized");

        //SHOULD there be a limit on number of open arbitration cases?
        
        //generate a unique id
        bytes32 arbId = bytes32(keccak256(abi.encodePacked(escrowId, proposalCount+1)));
        proposals[arbId].id = arbId;
        proposals[arbId].escrowId = escrowId;
        proposals[arbId].proposalType = proposalType;
        proposals[arbId].status = ArbitrationStatus.LIVE;
        proposals[arbId].votesAgainst = 0;

        //record proposer as an automatic yes vote
        proposals[arbId].votesFor = 1;
        proposals[arbId].votes[msg.sender] = true;

        //raise event 
        emit ArbitrationProposed(proposals[arbId].id, proposals[arbId].escrowId, msg.sender);
    }

    function voteArbitration(bytes32 arbitrationId, bool vote) public virtual {

        /*
        WHO can vote on arbitration? 
        1. arbiters only
        */

        //get the arbitration proposal
        ArbitrationProposal storage proposal = proposals[arbitrationId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //validate the escrow id
        bytes32 escrowId = proposal.escrowId;
        require(escrowId != bytes32(0), "InvalidEscrow");

        //validate rights of voter
        require(_canVoteArbitration(escrowId, msg.sender), "Unauthorized");

        //verify that the proposal is in a state in which it can be voted

        //record vote 
        if (vote) {
            proposal.votesFor += 1;
        } else {
            proposal.votesAgainst += 1;
        }
        proposal.votes[msg.sender] = vote;

        //change the status; are there enough votes to execute?
        Escrow memory escrow = polyEscrow.getEscrow(proposal.escrowId);
        uint256 arbiterCount = escrow.arbiters.length;
        uint8 arbitersRequired = escrow.arbitersRequired;
        if (proposal.votesFor >= arbitersRequired) {
            proposal.status = ArbitrationStatus.ACCEPTED;
        }
        else if (proposal.votesAgainst >= (arbiterCount - arbitersRequired)) {
            proposal.status = ArbitrationStatus.REJECTED;
        }

        //raise event 
        emit VoteRecorded(proposal.id, proposal.escrowId, msg.sender);

        //TODO: auto-execute?
    }

    function executeProposal(bytes32 arbitrationId) public virtual {

        //get the arbitration proposal
        ArbitrationProposal storage proposal = proposals[arbitrationId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //validate the escrow id
        bytes32 escrowId = proposal.escrowId;
        require(escrowId != bytes32(0), "InvalidEscrow");

        //proposal must be accepted 
        require(proposal.status == ArbitrationStatus.ACCEPTED, "InvalidEscrowState");

        //execute 
        _executeProposal(arbitrationId);
    }

    function _canProposeArbitration(bytes32 escrowId, address account) internal view returns (bool) {
        Escrow memory escrow = polyEscrow.getEscrow(escrowId);
        return (account == escrow.payer || account == escrow.receiver);
    }

    function _canVoteArbitration(bytes32 escrowId, address account) internal view returns (bool) {
        Escrow memory escrow = polyEscrow.getEscrow(escrowId);
        for(uint8 n=0; n<escrow.arbiters.length; n++) {
            if (escrow.arbiters[n] == account)
                return true;
        }
        return false;
    }

    function _executeProposal(bytes32 arbitrationId) internal virtual {
        //override 
    }
}
