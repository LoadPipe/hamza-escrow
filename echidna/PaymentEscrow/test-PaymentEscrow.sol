// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../src/PaymentEscrow.sol";
import "../../src/SecurityContext.sol";
import "../../src/SystemSettings.sol";
import "../../src/inc/utils/Hevm.sol";

/**
 * @title test_PaymentEscrow
 *
 * Simulates escrow workflows for testing purposes. Includes methods for placing payments, releasing funds, and refunds.
 * Contains invariants to validate the correctness of escrow behaviors during fuzz testing.
 *
 * @author Hudson Headley
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract test_PaymentEscrow {
    address constant admin = address(0x00001); // privileged admin account
    address constant user3 = address(0x30000); // deployer of the contract

    address constant user1 = address(0x10000); // payer 1
    address constant user2 = address(0x20000); // receiver 1
    address constant user4 = address(0x40000); // receiver 2
    address constant user5 = address(0x50000); // payer 2
    address constant userDeadbeef = address(0xDeaDBeef); // placeholder address
    address constant vault = address(0x50000); // address where fees are sent

    PaymentEscrow escrow; // instance of the PaymentEscrow contract
    SecurityContext securityContext; // instance of the SecurityContext contract
    SystemSettings systemSettings; // instance of the SystemSettings contract

    uint256 call_count = 0; // keeps track of the number of payments made
    bool first_call = false; // whether the first payment has been placed
    bool first_call_released = false; // whether the first payment has been released

    bool payment_success = false; // tracks the success of payment placements
    bool release_success = false; // tracks the success of payment releases
    bool refund_success = false; // tracks the success of payment refunds

    /**
     * @dev Constructor initializes required contracts and ensures the contract has an initial balance.
     */
    constructor() payable {
        require(msg.value > 0, "Initial balance required");
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings, false);
    }

    /**
     * Places a payment into the escrow.
     *
     * @param amount The amount of the payment to be placed.
     * @param randomizePayer Determines which payer will be used.
     * @param randomizeReceiver Determines which receiver will be used.
     */
    function placePayment1(uint256 amount, bool randomizePayer, bool randomizeReceiver) public {
        if (amount > address(this).balance) {
            return; // skip if insufficient balance
        }

        address payer = randomizePayer ? user1 : user5;
        address receiver = randomizeReceiver ? user2 : user4;

        bytes32 paymentId = keccak256(abi.encodePacked(call_count, address(this)));
        PaymentInput memory input = PaymentInput(address(0), paymentId, receiver, payer, amount);

        require(address(payer).balance >= amount, "Payer does not have enough balance");

        hevm.prank(payer);
        (bool success, ) = address(escrow).call{value: amount}(
            abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
        );

        payment_success = success;
        if (success) {
            call_count++;
        }
    }

    /**
     * Releases funds from the escrow for a specific payment.
     *
     * @param i The index of the payment to be released.
     */
    function releaseEscrow1(uint256 i) public {
        if (i < call_count) {
            first_call_released = true;

            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));

            hevm.prank(msg.sender);
            (bool success, ) = address(escrow).call(
                abi.encodeWithSignature("releaseEscrow(bytes32)", paymentId)
            );

            release_success = success;
        }
    }

    /**
     * Refunds a payment from the escrow.
     *
     * @param i The index of the payment to be refunded.
     * @param amount The amount to be refunded.
     */
    function refundPayment1(uint256 i, uint256 amount) public {
        if (i < call_count) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));

            hevm.prank(msg.sender);
            (bool success, ) = address(escrow).call(
                abi.encodeWithSignature("refundPayment(bytes32,uint256)", paymentId, amount)
            );

            refund_success = success;
        }
    }

    /**
     * Invariant: Ensures no payment has a zero amount.
     */
    function echidna_no_zero_payment_amount() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);
            if (payment.amount == 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures payments are not marked as released unless both payer and receiver agree.
     */
    function echidna_no_incorrectly_released_payments() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);
            if (payment.released && !(payment.payerReleased && payment.receiverReleased)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures escrow has sufficient funds to cover all refunds.
     */
    function echidna_escrow_funds_sufficient() public view returns (bool) {
        uint256 totalRefunded = 0;
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);
            totalRefunded += payment.amountRefunded;
            totalAmount += payment.amount;
            if (totalAmount < totalRefunded) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures payers and receivers are valid addresses.
     */
    function echidna_valid_payer_and_receiver() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            bool validPayer = (payment.payer == user1 || payment.payer == user5);
            bool validReceiver = (payment.receiver == user2 || payment.receiver == user4);

            if (!validPayer || !validReceiver) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures escrow balance can cover all locked funds.
     */
    function echidna_escrow_balance_sufficient() public view returns (bool) {
        uint256 totalLocked = 0;

        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            if (!payment.released) {
                totalLocked += (payment.amount - payment.amountRefunded);
            }
        }
        return address(escrow).balance >= totalLocked;
    }

    /**
     * Invariant: Ensures no refund exceeds the original payment amount.
     */
    function echidna_no_excess_refund_for_each_payment() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            if (payment.amountRefunded > payment.amount) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures no payment is both fully refunded and released.
     */
    function echidna_no_fully_refunded_and_released_payment() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            if (payment.amountRefunded == payment.amount && payment.released) {
                return false;
            }
        }
        return true;
    }
}
