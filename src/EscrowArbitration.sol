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

/**
 * @title Arbitration
 * 
 * Encapsulates the logic for proposing, voting on, and executing arbitration tasks such as refunding or 
 * releasing escrows via the assigned arbiters for the escrow. 
 * 
 * This contract is meant to be inherited by an escrow contract; this parent class will provide the basic 
 * logic for how proposals are to be managed and handled, including who is allowed to make and vote on 
 * proposals (for the given escrow). It has two links to the escrow logic: 
 * 1. polyEscrow (IPolyEscrow) property, passed in via the constructor, which (if implemented via inheritance as described) should really just be a reference to IPolyEscrow(this)
 * 2. the internal function _executeArbitration must be overriden (it's virtual & empty here - meant to be overriden or else proposals will not be executed)
 */
contract EscrowArbitration
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

    function proposeArbitration(bytes32 escrowId, ArbitrationType proposalType, uint256 amount) public virtual {

        /*
        WHO can propose arbitration? 
        1. the payer 
        2. the receiver 
        3. arbiters? 
        */
        require (_canProposeArbitration(escrowId, msg.sender), "Unauthorized");

        //TODO: should there be a limit on number of open arbitration cases?
        
        //generate a unique id
        bytes32 arbId = bytes32(keccak256(abi.encodePacked(escrowId, proposalCount+1)));
        proposals[arbId].id = arbId;
        proposals[arbId].escrowId = escrowId;
        proposals[arbId].proposalType = proposalType;
        proposals[arbId].amount = amount;
        proposals[arbId].status = ArbitrationStatus.ACTIVE;
        proposals[arbId].votesAgainst = 0;

        //TODO: validate the amount (should be realistic and related to amount in escrow)

        //record proposer as an automatic yes vote
        proposals[arbId].votesFor = 1;
        proposals[arbId].votes[msg.sender] = true;

        //raise event 
        emit ArbitrationProposed(proposals[arbId].id, proposals[arbId].escrowId, msg.sender);
    }

    function voteArbitration(bytes32 arbitrationId, bool vote) public virtual {
        
        // WHO can vote on arbitration?  arbiters only

        //get the arbitration proposal
        ArbitrationProposal storage proposal = proposals[arbitrationId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //get the escrow id
        bytes32 escrowId = proposal.escrowId;

        //validate rights of voter
        require(_canVoteArbitration(escrowId, msg.sender), "Unauthorized");

        //verify that the proposal is in a state in which it can be voted
        require(proposal.status == ArbitrationStatus.ACTIVE, "InvalidProposalState");

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

    function cancelArbitration(bytes32 arbitrationId) public virtual {

        //TODO: WHO can cancel arbitration?
        //TODO: all arbitration on an escrow should be cancelled if the seller takes any action

        //get the arbitration proposal
        //TODO: this code is repeated alot; can it be put into its own function
        ArbitrationProposal storage proposal = proposals[arbitrationId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        proposal.status = ArbitrationStatus.CANCELED;
    }

    function executeArbitration(bytes32 arbitrationId) public virtual {

        //get the arbitration proposal
        ArbitrationProposal storage proposal = proposals[arbitrationId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //proposal must be accepted 
        require(proposal.status == ArbitrationStatus.ACCEPTED, "InvalidEscrowState");

        //TODO: re-validate the amount (adjust it if necessary)

        //execute 
        _executeArbitration(proposal);

        //TODO: emit event
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

    function _executeArbitration(ArbitrationProposal storage /*proposal*/) internal virtual {
        revert("NotImplemented");
    }
}
