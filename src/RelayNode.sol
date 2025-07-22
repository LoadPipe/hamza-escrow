// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IPolyEscrow.sol";
import "./Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RelayNode is Pausable {
    IPolyEscrow public escrowContract;
    bytes32 public escrowId;

    constructor(ISecurityContext securityContext, IPolyEscrow _contractAddress, bytes32 _escrowId) 
        Pausable(securityContext) 
    {
        escrowContract = _contractAddress;
        escrowId = _escrowId;

        //validate escrow id 
        Escrow memory escrow = escrowContract.getEscrow(escrowId);
        require(escrow.id == escrowId, "InvalidEscrow");
    }

    function relay() public whenNotPaused {
        Escrow memory escrow = escrowContract.getEscrow(escrowId);

        // Perform actions based on the escrow data
        // For example, you can check the status of the escrow
        if (escrow.status == EscrowStatus.Pending) {
            if (escrow.currency == address(0)) {
                escrowContract.placePayment{ value: address(this).balance }(PaymentInput({
                    escrowId: escrow.id,
                    amount: escrow.amount - escrow.amountPaid,
                    currency: escrow.currency
                }));
            } else {
                IERC20 token = IERC20(escrow.currency);
                token.approve(address(escrowContract), token.balanceOf(address(this)));
                escrowContract.placePayment(PaymentInput({
                    escrowId: escrow.id,
                    amount: escrow.amount - escrow.amountPaid,
                    currency: escrow.currency
                }));
            }
        } else if (escrow.status == EscrowStatus.Completed) {
            // Logic for completed escrow
        } else if (escrow.status == EscrowStatus.Arbitration) {
            // Logic for arbitration
        }
        
        // Additional logic can be added here as needed
    }

    //TODO: implement
    function refundAll(address currency) public whenNotPaused {
        Escrow memory escrow = escrowContract.getEscrow(escrowId);
        address payer = escrow.payer;

        if (currency == address(0)) {
            //TODO: implement native refund
        }
        else {
            IERC20 token = IERC20(currency);
            uint256 balance = token.balanceOf(address(this));
            require(balance > 0, "NoBalance");
            require(token.transfer(payer, balance), "RefundFailed");
        }
    }

    receive() external payable {}
}