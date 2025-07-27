// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Types.sol";
import "./interfaces/IPolyEscrow.sol";
import "./interfaces/IArbitrationModule.sol";

/**
 * @title ArbitrationModule
 * 
 * Encapsulates the logic for proposing, voting on, and executing arbitration tasks such as refunding or 
 * releasing escrows via the assigned arbiters for the escrow. 
 * 
 * This contract is meant to be called by any PolyEscrow contract; the PolyEscrow contract just passes its
 * own address in to each method call. 
 */
contract ArbitrationModule is IArbitrationModule
{
    mapping(bytes32 => ArbitrationProposal) private proposals;
    mapping(bytes32 => mapping(address => bool)) proposalVotes;
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

    constructor() {
    }

    function getProposal(bytes32 proposalId) external virtual view returns (ArbitrationProposal memory) {
        return proposals[proposalId];
    }

    function proposeArbitration(IPolyEscrow polyEscrow, bytes32 escrowId, ArbitrationType proposalType, uint256 amount) external virtual {

        /*
        WHO can propose arbitration? 
        1. the payer 
        2. the receiver 
        3. arbiters? 
        */
        //require (_canProposeArbitration(polyEscrow, escrowId, msg.sender), "Unauthorized");

        //TODO: should there be a limit on number of open arbitration cases?
        
        //generate a unique id
        bytes32 propId = _generateUniqueProposalId(polyEscrow, escrowId);
        proposals[propId].id = propId;
        proposals[propId].escrowId = escrowId;
        proposals[propId].proposalType = proposalType;
        proposals[propId].amount = amount;
        proposals[propId].status = ArbitrationStatus.ACTIVE;
        proposals[propId].votesAgainst = 0;

        //TODO: validate the amount (should be realistic and related to amount in escrow)

        //record proposer as an automatic yes vote
        proposals[propId].votesFor = 1;
        proposalVotes[propId][msg.sender] = true;

        //raise event 
        emit ArbitrationProposed(proposals[propId].id, proposals[propId].escrowId, msg.sender);
    }

    function voteArbitration(IPolyEscrow polyEscrow, bytes32 proposalId, bool vote) external virtual {
        
        // WHO can vote on arbitration?  arbiters only

        //get the arbitration proposal
        ArbitrationProposal storage proposal = proposals[proposalId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //get the escrow id
        bytes32 escrowId = proposal.escrowId;

        //validate rights of voter
        require(_canVoteArbitration(polyEscrow, escrowId, msg.sender), "Unauthorized");

        //verify that the proposal is in a state in which it can be voted
        require(proposal.status == ArbitrationStatus.ACTIVE, "InvalidProposalState");

        //record vote 
        if (vote) {
            proposal.votesFor += 1;
        } else {
            proposal.votesAgainst += 1;
        }
        proposalVotes[proposalId][msg.sender] = vote;

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

    function cancelArbitration(bytes32 proposalId) external virtual {

        //TODO: WHO can cancel arbitration?
        //TODO: all arbitration on an escrow should be cancelled if the seller takes any action

        //get the arbitration proposal
        //TODO: this code is repeated alot; can it be put into its own function
        ArbitrationProposal storage proposal = proposals[proposalId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //TODO: can only cancel if status is ACTIVE

        proposal.status = ArbitrationStatus.CANCELED;
    }

    function executeArbitration(IPolyEscrow polyEscrow, bytes32 proposalId) external virtual view {

        //get the arbitration proposal
        ArbitrationProposal storage proposal = proposals[proposalId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //proposal must be accepted 
        require(proposal.status == ArbitrationStatus.ACCEPTED, "InvalidEscrowState");

        //TODO: re-validate the amount (adjust it if necessary)

        //execute 
        _executeArbitration(polyEscrow, proposal);

        //TODO: emit event
    }


    function _canProposeArbitration(IPolyEscrow polyEscrow, bytes32 escrowId, address account) internal view returns (bool) {
        Escrow memory escrow = polyEscrow.getEscrow(escrowId);
        return (account == escrow.payer || account == escrow.receiver);
    }

    function _canVoteArbitration(IPolyEscrow polyEscrow, bytes32 escrowId, address account) internal view returns (bool) {
        Escrow memory escrow = polyEscrow.getEscrow(escrowId);
        for(uint8 n=0; n<escrow.arbiters.length; n++) {
            if (escrow.arbiters[n] == account)
                return true;
        }
        return false;
    }

    function _executeArbitration(IPolyEscrow /*polyEscrow*/, ArbitrationProposal storage /*proposal*/) internal pure {
        revert("NotImplemented");
    }

    function _generateUniqueProposalId(IPolyEscrow polyEscrow, bytes32 escrowId) internal view returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(address(polyEscrow), escrowId, proposalCount+1)));
    }
}
