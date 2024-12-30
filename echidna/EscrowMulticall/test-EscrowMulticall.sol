// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../src/PaymentEscrow.sol";
import "../../src/EscrowMulticall.sol";
import "../../src/SecurityContext.sol";
import "../../src/SystemSettings.sol";
import "../../src/inc/utils/Hevm.sol";

/**
 * @title test_EscrowMulticallInvariants
 *
 * Simulates the behavior of the EscrowMulticall contract. Includes test cases for multi-payment workflows,
 * release of funds, and refunds, while enforcing invariants to ensure the integrity of the escrow system.
 *
 * @author Hudson Headley
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract test_EscrowMulticallInvariants {
    // Predefined test accounts
    address constant admin = address(0x00001); // privileged admin account
    address constant user3 = address(0x30000); // deployer account
    address constant user1 = address(0x10000); // first payer
    address constant user2 = address(0x20000); // first receiver
    address constant user4 = address(0x40000); // second receiver
    address constant user5 = address(0x50000); // second payer
    address constant userDeadbeef = address(0xDeaDBeef); // placeholder address
    address constant vault = address(0x99999); // vault address for fee deposits

    // Contracts used in the test setup
    EscrowMulticall public multi; // instance of EscrowMulticall contract
    SecurityContext public securityContext; // instance of SecurityContext contract
    SystemSettings public systemSettings; // instance of SystemSettings contract
    PaymentEscrow[] public escrows; // list of PaymentEscrow instances

    // Records payments made via the multicall functionality
    struct PaymentRecord {
        PaymentEscrow escrow; 
        bytes32 paymentId;
    }

    PaymentRecord[] public allPayments; // stores all payment records

    // Tracks success or failure of payment, release, and refund operations
    bool public payment_success = false;
    bool public release_success = false;
    bool public refund_success = false;

    /**
     * @dev Constructor initializes the test environment by deploying required contracts.
     * Ensures an initial balance for the test contract.
     */
    constructor() payable {
        require(msg.value > 0, "Initial balance required");

        // Initialize security context and system settings
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);

        // Deploy multiple PaymentEscrow contracts
        for (uint256 i = 0; i < 3; i++) {
            PaymentEscrow e = new PaymentEscrow(securityContext, systemSettings, false);
            escrows.push(e);
        }

        // Deploy the EscrowMulticall contract
        multi = new EscrowMulticall();
    }

    /**
     * Simulates a multi-payment transaction through EscrowMulticall.
     *
     * @param amount The amount for the payment.
     * @param randomizePayer Whether to randomize the payer.
     * @param randomizeReceiver Whether to randomize the receiver.
     * @param escrowIndex The index of the target escrow.
     */
    function multiPay1(
        uint256 amount, 
        bool randomizePayer, 
        bool randomizeReceiver, 
        uint256 escrowIndex
    ) public {
        // Ensure the escrow index is valid
        if (escrowIndex >= escrows.length) return;

        // Ensure sufficient balance to make the payment
        if (amount > address(this).balance) return;

        // Select payer and receiver
        address payer = randomizePayer ? user1 : user5;
        address receiver = randomizeReceiver ? user2 : user4;

        // Target the specified PaymentEscrow instance
        PaymentEscrow target = escrows[escrowIndex];

        // Generate a unique payment ID
        bytes32 paymentId = keccak256(
            abi.encodePacked(
                allPayments.length, 
                address(this),
                escrowIndex
            )
        );

        // Prepare input for the multipay function
        MulticallPaymentInput[] memory inputs = new MulticallPaymentInput[](1);

        inputs[0] = MulticallPaymentInput({
            contractAddress: address(target),
            currency: address(0), // use native currency
            id: paymentId,
            receiver: receiver,
            payer: payer,
            amount: amount
        });

        // Perform the multipay operation
        hevm.prank(payer);
        (bool success, ) = address(multi).call{value: amount}(
            abi.encodeWithSignature("multipay((address,address,bytes32,address,address,uint256)[])", inputs)
        );

        payment_success = success;

        if (success) {
            // Record the successful payment
            allPayments.push(
                PaymentRecord({
                    escrow: target,
                    paymentId: paymentId
                })
            );
        }
    }

    /**
     * Simulates releasing funds for a specific payment.
     *
     * @param index The index of the payment to release.
     */
    function releaseEscrow1(uint256 index) public {
        if (index < allPayments.length) {
            PaymentRecord memory record = allPayments[index];

            hevm.prank(msg.sender);
            (bool success, ) = address(record.escrow).call(
                abi.encodeWithSignature("releaseEscrow(bytes32)", record.paymentId)
            );

            release_success = success;
        }
    }

    /**
     * Simulates refunding a specific payment.
     *
     * @param index The index of the payment to refund.
     * @param amount The amount to refund.
     */
    function refundPayment1(uint256 index, uint256 amount) public {
        if (index < allPayments.length) {
            PaymentRecord memory record = allPayments[index];

            hevm.prank(msg.sender);
            (bool success, ) = address(record.escrow).call(
                abi.encodeWithSignature("refundPayment(bytes32,uint256)", record.paymentId, amount)
            );

            refund_success = success;
        }
    }

    /**
     * Invariant: Ensures no payment has a zero amount.
     */
    function echidna_no_zero_payment_amount() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);
            if (paymentData.amount == 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures no payment is released without both parties agreement
     */
    function echidna_no_incorrectly_released_payments() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);
            if (paymentData.released && !(paymentData.payerReleased && paymentData.receiverReleased)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures refunded amounts do not exceed the original payment
     */
    function echidna_escrow_funds_sufficient_per_payment() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);
            if (paymentData.amountRefunded > paymentData.amount) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures valid payers and receivers for all payments.
     */
    function echidna_valid_payer_and_receiver() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);

            bool validPayer = (paymentData.payer == user1 || paymentData.payer == user5);
            bool validReceiver = (paymentData.receiver == user2 || paymentData.receiver == user4);

            if (!validPayer || !validReceiver) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures escrow balances cover all locked funds.
     */
    function echidna_escrow_balance_sufficient_for_locked_funds() public view returns (bool) {
        uint256[] memory lockedBalances = new uint256[](escrows.length);

        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);

            if (!paymentData.released) {
                for (uint256 j = 0; j < escrows.length; j++) {
                    if (address(escrows[j]) == address(record.escrow)) {
                        lockedBalances[j] += (paymentData.amount - paymentData.amountRefunded);
                        break;
                    }
                }
            }
        }

        for (uint256 i = 0; i < escrows.length; i++) {
            if (address(escrows[i]).balance < lockedBalances[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures no payment is both fully refunded and released.
     */
    function echidna_no_fully_refunded_and_released_payment() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);

            if (paymentData.amountRefunded == paymentData.amount && paymentData.released) {
                return false;
            }
        }
        return true;
    }
}
