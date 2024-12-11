// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PaymentInput.sol";
import "./IEscrowContract.sol";

/* Encapsulates information about an incoming payment
*/
struct MulticallPaymentInput
{
    address contractAddress;
    address currency; //token address, or 0x0 for native 
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
}

/**
 * @title EscrowMulticall
 * 
 * Allows multiple payments to be passed in and routed to the appropriate escrow contracts.
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract EscrowMulticall
{
    constructor() {}
    
    /**
     * Accepts multiple inputs for payments, each of which can be in a different currency and 
     * passed to a different escrow contract. 
     * 
     * Reverts: 
     * - 'InsufficientAmount': if amount of native ETH sent is not equal to the declared amount. 
     * - 'TokenTransferFailed': if the token transfer from sender to this contract fails for any reason (e.g. insufficient allowance)
     * - 'TokenPaymentFailure': if token transfer to the escrow fails for any reason (e.g. insufficial allowance)
     * - 'DuplicatePayment': if payment id exists already 
     * - 'PaymentFailure': if native payment transfer to escrow fails for any reason
     * 
     * Calls: PaymentEscrow.placePayment
     * 
     * @param payments Array of payment specifications, each to be passed to a different escrow.
     */
    function multipay(MulticallPaymentInput[] calldata payments) external payable {
        for (uint256 n=0; n<payments.length; n++) {
            MulticallPaymentInput memory payment = payments[n];

            uint256 amount = payment.amount;

            if (payment.currency == address(0)) {
                //check that the amount matches
                if (msg.value < amount)
                    revert("InsufficientAmount");

                //then forward the payment & call to the contract 
                PaymentInput memory input = PaymentInput(payment.currency, payment.id, payment.receiver, payment.payer, payment.amount);
                (bool success, ) = payment.contractAddress.call{value: payment.amount}(
                    abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
                );

                if (!success) {
                    revert("PaymentFailure");
                }
            } 
            else {
                //transfer to self 
                IERC20 token = IERC20(payment.currency);
                if (!token.transferFrom(msg.sender, address(this), amount))
                    revert('TokenTransferFailed'); 

                //then forward the payment & call to the contract 
                token.approve(payment.contractAddress, amount);

                PaymentInput memory input = PaymentInput(payment.currency, payment.id, payment.receiver, payment.payer, payment.amount);
                (bool success, ) = payment.contractAddress.call{value: 0}(
                    abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
                );

                if (!success) {
                    revert("TokenPaymentFailure");
                }
            }
        }
    }

    receive() external payable {}
}