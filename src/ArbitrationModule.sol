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

    function proposeArbitration(IPolyEscrow polyEscrow, bytes32 escrowId, ArbitrationType proposalType, uint256 amount, bool autoExecute) external virtual {

        /*
        WHO can propose arbitration? 
        1. the payer 
        2. the receiver 
        3. arbiters? 
        */

        //ensure that escrow is valid 
        //EXCEPTION: InvalidEscrow
        require(polyEscrow.getEscrow(escrowId).id == escrowId, "InvalidEscrow");

        //EXCEPTION: Unauthorized
        require (_canProposeArbitration(polyEscrow, escrowId, msg.sender), "Unauthorized");

        //EXCEPTION: InvalidEscrowState
        require(_escrowStateIsValid(polyEscrow, escrowId), "InvalidEscrowState");

        //TODO: should there be a limit on number of open arbitration cases?

        //TODO: ensure that escrow is in correct state to be arbitrated
        
        //generate a unique id
        bytes32 propId = _generateUniqueProposalId(polyEscrow, escrowId);
        proposals[propId].id = propId;
        proposals[propId].escrowId = escrowId;
        proposals[propId].proposalType = proposalType;
        proposals[propId].amount = amount;
        proposals[propId].status = ArbitrationStatus.ACTIVE;
        proposals[propId].votesAgainst = 0;
        proposals[propId].autoExecute = autoExecute;
        proposals[propId].proposer = msg.sender;

        //TODO: validate the amount (should be realistic and related to amount in escrow)

        //record proposer as an automatic yes vote, if proposer is a voter
        if (_canVoteArbitration(polyEscrow, escrowId, msg.sender)) {
            _voteArbitration(polyEscrow, proposals[propId], true);
        }

        //raise event 
        emit ArbitrationProposed(proposals[propId].id, proposals[propId].escrowId, msg.sender);
    }

    function voteArbitration(IPolyEscrow polyEscrow, bytes32 proposalId, bool vote) external virtual {
        
        // WHO can vote on arbitration?  arbiters only

        //get the arbitration proposal
        //EXCEPTION: InvalidProposal
        ArbitrationProposal storage proposal = proposals[proposalId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //get the escrow id
        bytes32 escrowId = proposal.escrowId;

        //ensure that escrowId is valid with escrow
        //EXCEPTION: InvalidEscrow
        require(polyEscrow.getEscrow(escrowId).id == escrowId, "InvalidEscrow");

        //TODO: ensure that escrow is in correct state to be voted on

        //validate rights of voter
        //EXCEPTION: Unauthorized
        require(_canVoteArbitration(polyEscrow, escrowId, msg.sender), "Unauthorized");

        //verify that the proposal is in a state in which it can be voted
        //EXCEPTION: InvalidProposalState
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
            
            // Auto-execute if autoExecute flag is true
            if (proposal.autoExecute) {
                _executeArbitration(polyEscrow, proposal);
            }
        }
        else if (proposal.votesAgainst >= (arbiterCount - arbitersRequired)) {
            proposal.status = ArbitrationStatus.REJECTED;
        }

        //raise event 
        emit VoteRecorded(proposal.id, proposal.escrowId, msg.sender);
    }

    function cancelArbitration(bytes32 proposalId) external virtual {
        //get the arbitration proposal
        //EXCEPTION: InvalidProposal 
        ArbitrationProposal storage proposal = proposals[proposalId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //only the proposer can cancel 
        //EXCEPTION: Unauthorized 
        require(proposal.proposer == msg.sender, "Unauthorized");

        //TODO: all arbitration on an escrow should be cancelled if the seller takes any action

        //can only cancel if status is ACTIVE
        //EXCEPTION: NotCancellable
        require(proposal.status == ArbitrationStatus.ACTIVE, "NotCancellable");

        //can only cancel if no votes have been cast
        //EXCEPTION: NotCancellable
        require(proposal.votesFor == 0 && proposal.votesAgainst == 0, "NotCancellable");

        proposal.status = ArbitrationStatus.CANCELED;
    }

    function executeArbitration(IPolyEscrow polyEscrow, bytes32 proposalId) external virtual {

        //get the arbitration proposal
        //EXCEPTION: InvalidProposal 
        ArbitrationProposal storage proposal = proposals[proposalId];
        require(proposal.id != bytes32(0), "InvalidProposal");

        //proposal must be accepted 
        //EXCEPTION: InvalidEscrowState 
        require(proposal.status == ArbitrationStatus.ACCEPTED, "InvalidEscrowState");

        //TODO: re-validate the amount (adjust it if necessary)

        //get the escrow id
        bytes32 escrowId = proposal.escrowId;

        //ensure that escrowId is valid with escrow
        //EXCEPTION: InvalidEscrow 
        require(polyEscrow.getEscrow(escrowId).id == escrowId, "InvalidEscrow");

        //TODO: ensure that escrow is in correct state to have arbitration executed

        //execute 
        _executeArbitration(polyEscrow, proposal);

        //TODO: emit event
    }

    function isArbitrationModule() external pure returns (bool) {
        return true; 
    }


    // --- NON-PUBLIC METHODS --- 
    

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

    function _executeArbitration(IPolyEscrow polyEscrow, ArbitrationProposal storage proposal) internal {
        polyEscrow.executeArbitrationProposal(proposal.escrowId, proposal.proposalType, proposal.amount);
        proposal.status = ArbitrationStatus.EXECUTED;
        emit ProposalExecuted(proposal.id, proposal.escrowId, msg.sender);
    }

    function _generateUniqueProposalId(IPolyEscrow polyEscrow, bytes32 escrowId) internal view returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(address(polyEscrow), escrowId, proposalCount+1)));
    }

    function _escrowStateIsValid(IPolyEscrow polyEscrow, bytes32 escrowId) internal view returns (bool) {
        Escrow memory escrow = polyEscrow.getEscrow(escrowId);
        return escrow.status != EscrowStatus.Completed;

        //TODO: should also include Pending?
    }

    function _voteArbitration(IPolyEscrow polyEscrow, ArbitrationProposal storage proposal, bool vote) internal {

        //record vote 
        if (vote) {
            proposal.votesFor += 1;
        } else {
            proposal.votesAgainst += 1;
        }
        proposalVotes[proposal.id][msg.sender] = vote;

        //change the status; are there enough votes to execute?
        Escrow memory escrow = polyEscrow.getEscrow(proposal.escrowId);
        uint256 arbiterCount = escrow.arbiters.length;
        uint8 arbitersRequired = escrow.arbitersRequired;
        if (proposal.votesFor >= arbitersRequired) {
            proposal.status = ArbitrationStatus.ACCEPTED;
            
            // Auto-execute if autoExecute flag is true
            if (proposal.autoExecute) {
                _executeArbitration(polyEscrow, proposal);
            }
        }
        else if (proposal.votesAgainst >= (arbiterCount - arbitersRequired)) {
            proposal.status = ArbitrationStatus.REJECTED;
        }

        //raise event 
        emit VoteRecorded(proposal.id, proposal.escrowId, msg.sender);
    }
}
