// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./HasSecurityContext.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//TODO: support for refunds 

/* Encapsulates information about an incoming payment
*/
struct PaymentInput
{
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
}

struct Payment 
{
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
    uint256 amountRefunded;
    bool payerReleased;
    bool receiverReleased;
    bool released;
    address currency; //token address, or 0x0 for native 
}

struct MultiPaymentInput 
{
    address currency; //token address, or 0x0 for native 
    PaymentInput[] payments;
}

/**
 * @title PaymentEscrow
 * 
 * Takes in funds from marketplace, extracts a fee, and batches the payments for transfer
 * to the appropriate parties, holding the funds in escrow in the meantime. 
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract PaymentEscrow is HasSecurityContext
{
    address public vaultAddress; 
    mapping(bytes32 => Payment) private payments;

    //EVENTS 
    event VaultAddressChanged (
        address newAddress,
        address changedBy
    );

    event PaymentReceived (
        bytes32 indexed paymentId,
        address indexed to,
        address from, 
        address currency, 
        uint256 amount 
    );

    event PaymentSwept (
        bytes32 indexed paymentId, 
        address currency, 
        uint256 amount 
    );

    event PaymentSweepFailed (
        bytes32 indexed paymentId, 
        address currency, 
        uint256 amount 
    );
    
    /**
     * Constructor. 
     * 
     * Emits: 
     * - {HasSecurityContext-SecurityContextSet}
     * 
     * Reverts: 
     * - {ZeroAddressArgument} if the securityContext address is 0x0. 
     * 
     * @param securityContext Contract which will define & manage secure access for this contract. 
     * @param vault Recipient of the extracted fees. 
     */
    constructor(ISecurityContext securityContext, address vault) {
        _setSecurityContext(securityContext);
        if (vault == address(0)) 
            revert("InvalidVaultAddress");
        vaultAddress = vault;
    }

    /**
     * Sets the address to which fees are sent. 
     * 
     * Emits: 
     * - {MasterSwitch-VaultAddressChanged} 
     * 
     * Reverts: 
     * - 'AccessControl:' if caller is not authorized as ARBITER_ROLE. 
     * 
     * @param _vaultAddress The new address. 
     */
    function setVaultAddress(address _vaultAddress) public onlyRole(ARBITER_ROLE) {
        if (_vaultAddress != vaultAddress) {
            vaultAddress = _vaultAddress;
            emit VaultAddressChanged(_vaultAddress, msg.sender);
        }
    }

    function releaseEscrow(bytes32 paymentId) external {
        Payment storage payment = payments[paymentId];
        if (payment.amount > 0) {
            if (payment.receiver == msg.sender) {
                payment.receiverReleased = true;
            }
            if (payment.payer == msg.sender) {
                payment.payerReleased = true;
            }

            _releaseEscrowPayment(paymentId);
        }
    }

    function refundPayment(bytes32 paymentId, uint256 amount) external {
        Payment storage payment = payments[paymentId]; 
        if (payment.amount > 0 && payment.amountRefunded <= payment.amount) {

            //who has permission to refund? either the receiver or the arbiter
            if (payment.receiver != msg.sender && !securityContext.hasRole(ARBITER_ROLE, msg.sender))
                revert("Unauthorized");

            uint256 activeAmount = payment.amount - payment.amountRefunded; 

            if (amount > activeAmount) 
                amount = activeAmount; 

            //transfer amount back to payer 
            if (amount > 0) {
                if (_transferAmount(payment.id, payment.payer, payment.currency, amount))
                    payment.amountRefunded += amount;
            }
        }
    }

    function releaseEscrowOnBehalfOfPayer(bytes32 paymentId) onlyRole(ARBITER_ROLE) external {
        Payment storage payment = payments[paymentId];
        if (payment.amount > 0) {
            payment.payerReleased = true;
            _releaseEscrowPayment(paymentId);
        }
    }
    
    /**
     * Allows multiple payments to be processed. 
     * 
     * @param multiPayments Array of payment definitions
     */
    function placeMultiPayments(MultiPaymentInput[] calldata multiPayments) public payable {
        for(uint256 i=0; i<multiPayments.length; i++) {
            MultiPaymentInput memory multiPayment = multiPayments[i];
            address currency = multiPayment.currency; 
            uint256 amount = _getPaymentTotal(multiPayment);

            if (currency == address(0)) {
                //check that the amount matches
                if (msg.value < amount)
                    revert("InsufficientAmount");
            } 
            else {
                //transfer to self 
                IERC20 token = IERC20(currency);
                if (!token.transferFrom(msg.sender, address(this), amount))
                    revert('TokenPaymentFailed'); 
            }

            //add payments to internal map, emit events for each individual payment
            for(uint256 n=0; n<multiPayment.payments.length; n++) {
                PaymentInput memory paymentInput = multiPayment.payments[i];

                //add payment to mapping 
                Payment memory payment = payments[paymentInput.id];
                payment.payer = paymentInput.payer;
                payment.receiver = paymentInput.receiver;
                payment.currency = multiPayment.currency;
                payment.amount = paymentInput.amount;
                payment.id = paymentInput.id;

                //emit event
                emit PaymentReceived(
                    payment.id, 
                    payment.receiver, 
                    payment.payer, 
                    payment.currency, 
                    payment.amount
                );
            }
        }
    }

    function _getPaymentTotal(MultiPaymentInput memory input) internal pure returns (uint256) {
        uint256 output = 0;
        for(uint256 n=0; n<input.payments.length; n++) {
            output += input.payments[n].amount;
        }
        return output;
    }

    function _releaseEscrowPayment(bytes32 paymentId) internal {
        Payment storage payment = payments[paymentId];
        if (payment.payerReleased && payment.receiverReleased && !payment.released) {
            //transfer funds 
            if (!payment.released) {
                if (_transferAmount(
                    payment.id, 
                    payment.receiver, 
                    payment.currency, 
                    payment.amount - payment.amountRefunded
                )) {
                    payment.released = true;
                }
            }
        }
    }

    function _transferAmount(bytes32 paymentId, address to, address tokenAddressOrZero, uint256 amount) internal returns (bool) {
        bool success = false; 

        if (amount > 0) {
            if (tokenAddressOrZero == address(0)) {
                (success,) = payable(to).call{value: amount}("");
            } 
            else {
                IERC20 token = IERC20(tokenAddressOrZero); 
                success = token.transfer(to, amount);
            }

            if (success) {
                emit PaymentSwept(paymentId, tokenAddressOrZero, amount);
            }
            else {
                emit PaymentSweepFailed(paymentId, tokenAddressOrZero, amount);
            }
        }

        return success;
    }

    receive() external payable {}
}