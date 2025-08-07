// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Types.sol";
import "./interfaces/IPolyEscrow.sol";
import "./interfaces/IArbitrationModule.sol";
import "hardhat/console.sol";

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
    uint8 public constant MAX_ARBITRATION_CASES = 3;
    
    mapping(bytes32 => ArbitrationProposal) private proposals;
    mapping(bytes32 => mapping(address => VoteState)) proposalVotes; 
    uint8 public proposalCount;
    uint8 public activeProposalCount;

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

       //get the relevant escrow
        //EXCEPTION: InvalidEscrow
        //EXCEPTION: InvalidArbitrationModule
        Escrow memory escrow = _getAndCheckEscrow(polyEscrow, escrowId);

        //EXCEPTION: Unauthorized
        require (_canProposeArbitration(polyEscrow, escrowId, msg.sender), "Unauthorized");

        //EXCEPTION: InvalidEscrowState
        require(_escrowStateIsValid(polyEscrow, escrowId), "InvalidEscrowState");

        //EXCEPTION: MaxArbitrationCasesReached
        //Check if maximum number of active arbitration cases has been reached
        require(activeProposalCount < MAX_ARBITRATION_CASES, "MaxArbitrationCasesReached");

        //EXCEPTION: InvalidProposalAmount
        //Validate the arbitration amount
        require(amount <= escrow.amountPaid - escrow.amountRefunded - escrow.amountReleased, "InvalidProposalAmount");
        
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

        //record proposer as an automatic yes vote, if proposer is a voter
        //TODO: especially test this case 
        if (_canVoteArbitration(polyEscrow, escrowId, msg.sender)) {
            _voteArbitration(polyEscrow, escrow, proposals[propId], true);
        }

        // Increment counters
        proposalCount++;
        activeProposalCount++;

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

       //get the relevant escrow
        //EXCEPTION: InvalidEscrow
        //EXCEPTION: InvalidArbitrationModule
        Escrow memory escrow = _getAndCheckEscrow(polyEscrow, escrowId);

        //validate rights of voter
        //EXCEPTION: Unauthorized
        require(_canVoteArbitration(polyEscrow, escrowId, msg.sender), "Unauthorized");

        //verify that the proposal is in a state in which it can be voted
        //EXCEPTION: InvalidProposalState
        require(proposal.status == ArbitrationStatus.ACTIVE, "InvalidProposalState");

        //record vote 
        _voteArbitration(polyEscrow, escrow, proposal, vote);
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
        
        //TODO: can only cancel if status is ACTIVE
        require(proposal.status == ArbitrationStatus.ACTIVE, "InvalidProposalState");

        proposal.status = ArbitrationStatus.CANCELED;
        activeProposalCount--;
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

       //get the relevant escrow
        //EXCEPTION: InvalidEscrow
        //EXCEPTION: InvalidArbitrationModule
        _getAndCheckEscrow(polyEscrow, escrowId);

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
        activeProposalCount--;
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

    function _voteArbitration(IPolyEscrow polyEscrow, Escrow memory escrow, ArbitrationProposal storage proposal, bool vote) internal {

        //record vote 
        if (proposalVotes[proposal.id][msg.sender] == VoteState.NULL) {
            //this voter has not yet voted on this proposal
            if (vote) {
                proposal.votesFor += 1;
                proposalVotes[proposal.id][msg.sender] = VoteState.YEA;
            } else {
                proposal.votesAgainst += 1;
                proposalVotes[proposal.id][msg.sender] = VoteState.NAY;
            }
        }
        else {
            //this voter has voted before, may be changing vote 
            if (vote && proposalVotes[proposal.id][msg.sender] == VoteState.NAY) {
                //change vote from nay to yea
                proposal.votesFor += 1;
                proposal.votesAgainst -= 1;
                proposalVotes[proposal.id][msg.sender] = VoteState.YEA;
            } 
            else if (!vote && proposalVotes[proposal.id][msg.sender] == VoteState.YEA) {
                //change vote from yea to nay
                proposal.votesFor -= 1;
                proposal.votesAgainst += 1;
                proposalVotes[proposal.id][msg.sender] = VoteState.NAY;
            }
        }

        //change the status; are there enough votes to execute?
        uint256 arbiterCount = escrow.arbiters.length;
        uint8 arbitersRequired = escrow.arbitersRequired;
        if (proposal.votesFor >= arbitersRequired) {
            proposal.status = ArbitrationStatus.ACCEPTED;
            
            // Auto-execute if autoExecute flag is true
            if (proposal.autoExecute) {
                _executeArbitration(polyEscrow, proposal);
            } else {
                // If not auto-executing, decrement active count since proposal is no longer ACTIVE
                activeProposalCount--;
            }
        }
        else if (proposal.votesAgainst > (arbiterCount - arbitersRequired)) {
            proposal.status = ArbitrationStatus.REJECTED;
            activeProposalCount--;
        }

        //raise event 
        emit VoteRecorded(proposal.id, proposal.escrowId, msg.sender);
    }

    function _getAndCheckEscrow(IPolyEscrow polyEscrow, bytes32 escrowId) internal view returns (Escrow memory) {

       //get the relevant escrow
        Escrow memory escrow = polyEscrow.getEscrow(escrowId);

        //ensure that escrow is valid 
        //EXCEPTION: InvalidEscrow
        require(escrow.id == escrowId, "InvalidEscrow");

        //Check that this is the right arbitration module for the given escrow
        //EXCEPTION: InvalidArbitrationModule
        require(address(escrow.arbitrationModule) == address(this), "InvalidArbitrationModule");

        //EXCEPTION: InvalidProposalNoArbiters
        require(escrow.arbiters.length > 0, "InvalidProposalNoArbiters");

        return escrow;
    }
}
