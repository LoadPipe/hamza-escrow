// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./PaymentEscrow.sol";
import "./PaymentInput.sol";
import "./SecurityContext.sol";
import "./SystemSettings.sol";

contract PaymentEscrowInvariant {
    PaymentEscrow escrow;

    constructor() {
        // Deploy SecurityContext and SystemSettings with pre-defined roles
        SecurityContext securityContext = new SecurityContext(address(this));
        SystemSettings systemSettings = new SystemSettings(
            ISecurityContext(address(securityContext)),
            address(0xC0FFEE), 
            0 // No fee
        );

        // Deploy PaymentEscrow contract
        escrow = new PaymentEscrow(
            ISecurityContext(address(securityContext)),
            ISystemSettings(address(systemSettings))
        );
    }

    // Invariant 1: Payment amount should never be less than the refunded amount
    function echidna_payment_cannot_exceed() public view returns (bool) {
        bytes32 paymentId = keccak256(abi.encodePacked("test"));
        Payment memory payment = escrow.getPayment(paymentId);
        return payment.amount >= payment.amountRefunded;
    }

    // Invariant 2: Payment cannot be released without payer and receiver consent
    function echidna_payment_needs_consent() public view returns (bool) {
        bytes32 paymentId = keccak256(abi.encodePacked("test"));
        Payment memory payment = escrow.getPayment(paymentId);
        return !payment.released || (payment.payerReleased && payment.receiverReleased);
    }

    // Empty function so excluded from foundry coverage 
    function test () public {}
}
