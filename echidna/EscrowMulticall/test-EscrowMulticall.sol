// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../src/PaymentEscrow.sol";
import "../../src/EscrowMulticall.sol";
import "../../src/HatsSecurityContext.sol";
import "../../src/SystemSettings.sol";
import "hevm/Hevm.sol";

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
    HatsSecurityContext public securityContext; // instance of SecurityContext contract
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

        Hats hats = new Hats("Test Hats", "ipfs://");
        
        uint256 topHatId = hats.mintTopHat(address(this), "Test Admin Hat", "ipfs://image");

        // Initialize security context and system settings
        securityContext = new HatsSecurityContext(address(hats), topHatId);
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
    * @dev multiPay1 that pays multiple escrows at once in one multipay call.
    *
    * @param totalAmount        The total amount to be distributed across multiple escrows.
    * @param randomizePayer     Whether to randomize the payer (user1 or user5).
    * @param randomizeReceiver  Whether to randomize the receiver (user2 or user4).
    * @param numberOfEscrows    How many escrow contracts to pay in this single transaction.
    */
    function multiPay1(
        uint256 totalAmount,
        bool randomizePayer,
        bool randomizeReceiver,
        uint256 numberOfEscrows
    ) public {
        // Ensure there's enough balance in this contract
        if (totalAmount > address(this).balance) {
            return;
        }

        // Use modulo to restrict 'numberOfEscrows' to the length of the escrows array
        if (escrows.length > 0) {
            numberOfEscrows = (numberOfEscrows % escrows.length) + 1; 
        } else {
            return; // If no escrows exist, exit the function
        }

        // Calculate how much goes to each escrow
        uint256 amountPerEscrow = totalAmount / numberOfEscrows;

        // If integer division yields 0, avoid zero-amount payments
        if (amountPerEscrow == 0) {
            return;
        }

        // Select payer and receiver
        address payer = randomizePayer ? user1 : user5;
        address receiver = randomizeReceiver ? user2 : user4;

        // Build MulticallPaymentInput array
        MulticallPaymentInput[] memory inputs = new MulticallPaymentInput[](numberOfEscrows);

        for (uint256 i = 0; i < numberOfEscrows; i++) {
            // Generate a unique payment ID
            bytes32 paymentId = keccak256(
                abi.encodePacked(
                    allPayments.length,
                    address(this),
                    i,
                    block.timestamp // extra entropy
                )
            );

            inputs[i] = MulticallPaymentInput({
                contractAddress: address(escrows[i % escrows.length]), // Ensure valid index
                currency: address(0),    // native currency
                id: paymentId,
                receiver: receiver,
                payer: payer,
                amount: amountPerEscrow
            });
        }

        // Invoke the multipay function in a single call
        hevm.prank(payer);
        (bool success, ) = address(multi).call{value: totalAmount}(
            abi.encodeWithSignature(
                "multipay((address,address,bytes32,address,address,uint256)[])",
                inputs
            )
        );

        payment_success = success;

        // Record all payments if successful
        if (success) {
            for (uint256 i = 0; i < numberOfEscrows; i++) {
                allPayments.push(
                    PaymentRecord({
                        escrow: PaymentEscrow(payable(inputs[i].contractAddress)),
                        paymentId: inputs[i].id
                    })
                );
            }
        }
    }



    /**
     * Simulates releasing funds for a specific payment.
     *
     * @param index The index of the payment to release.
     */
    function releaseEscrow1(uint256 index) public {
            index = index % allPayments.length;
            PaymentRecord memory record = allPayments[index];

            hevm.prank(msg.sender);
            (bool success, ) = address(record.escrow).call(
                abi.encodeWithSignature("releaseEscrow(bytes32)", record.paymentId)
            );

            release_success = success;
    }

    /**
     * Simulates refunding a specific payment.
     *
     * @param index The index of the payment to refund.
     * @param amount The amount to refund.
     */
    function refundPayment1(uint256 index, uint256 amount) public {
            index = index % allPayments.length;
            PaymentRecord memory record = allPayments[index];

            hevm.prank(msg.sender);
            (bool success, ) = address(record.escrow).call(
                abi.encodeWithSignature("refundPayment(bytes32,uint256)", record.paymentId, amount)
            );

            refund_success = success;
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
