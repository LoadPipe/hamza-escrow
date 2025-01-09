// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// --- Add these if they are not already in your repo structure or import paths ---
import "../../lib/hats-protocol/src/Hats.sol";
import "../../src/HatsSecurityContext.sol";
import "../../src/PaymentEscrow.sol";
import "../../src/SystemSettings.sol";
import "../../src/IHatsSecurityContext.sol";
import "../../src/ISystemSettings.sol";
import "../../src/PaymentInput.sol";

// Use the same cheat-code interface you were using, e.g. for hevm
import "../../src/inc/utils/Hevm.sol";

/**
 * @title test_PaymentEscrow
 *
 * Example Echidna test that integrates Hats, referencing the Foundry-based PaymentEscrowTest.
 */
contract test_PaymentEscrow {
    // --------------------//
    // Addresses Used      //
    // --------------------//
    address constant admin     = address(0x00001);
    address constant user3     = address(0x30000); // deployer
    address constant user1     = address(0x10000); // payer 1
    address constant user2     = address(0x20000); // receiver 1
    address constant user4     = address(0x40000); // receiver 2
    address constant user5     = address(0x50000); // payer 2
    address constant userDeadbeef = address(0xDeaDBeef);
    address constant vault     = address(0xF0005);  // vault for fees

    // --------------------//
    // Contracts           //
    // --------------------//
    PaymentEscrow public escrow;
    HatsSecurityContext public securityContext;
    SystemSettings public systemSettings;
    Hats public hats; // the Hats protocol itself

    // Example counters/flags used in your tests
    uint256 public call_count;
    bool public first_call;
    bool public first_call_released;

    bool public payment_success;
    bool public release_success;
    bool public refund_success;

    /**
     * @dev Deploy Hats, HatsSecurityContext, SystemSettings, and PaymentEscrow in the constructor.
     *      Then fund this contract with some Ether for testing flows that require native currency.
     */
    constructor() payable {
        // We assume you run echidna with some initial contract balance, e.g.:
        //   echidna test_PaymentEscrow.sol --contract test_PaymentEscrow --test-limit 1000 --fund-amount 1000000000000000000
        require(msg.value > 0, "Initial balance required");

        // 1. Deploy a Hats instance
        hats = new Hats("Test Hats", "ipfs://");

        // 2. Deploy your security context, passing in the hats address and some "admin hat" ID.
        //    For simplicity, we just pass `1` here, but in a more advanced scenario you'd first
        //    mint a top-hat to an admin and record that ID.
        securityContext = new HatsSecurityContext(address(hats), 1);

        // 3. Deploy system settings, referencing the security context
        systemSettings = new SystemSettings(IHatsSecurityContext(address(securityContext)), vault, 0);

        // 4. Deploy your PaymentEscrow with autoRelease = false (you can set this to true if desired)
        escrow = new PaymentEscrow(
            IHatsSecurityContext(address(securityContext)),
            ISystemSettings(address(systemSettings)),
            false
        );
    }

    /**
     * Places a payment into the escrow.
     *
     * @param amount The amount of the payment to be placed.
     * @param randomizePayer Determines which payer will be used.
     * @param randomizeReceiver Determines which receiver will be used.
     */
    function placePayment1(uint256 amount, bool randomizePayer, bool randomizeReceiver) public {
        // skip if insufficient balance in this contract
        if (amount > address(this).balance) {
            return; 
        }

        address payer    = randomizePayer    ? user1 : user5;
        address receiver = randomizeReceiver ? user2 : user4;

        bytes32 paymentId = keccak256(abi.encodePacked(call_count, address(this)));
        PaymentInput memory input = PaymentInput({
            currency: address(0), // assume native for now
            id: paymentId,
            receiver: receiver,
            payer: payer,
            amount: amount
        });

        // Make sure payer has enough balance for test
        if (payer.balance < amount) {
            return;
        }

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
            // If `payment.released == true` then it must be that both payerReleased and receiverReleased are true
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
        uint256 totalAmount   = 0;
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);
            totalRefunded += payment.amountRefunded;
            totalAmount   += payment.amount;
            if (totalAmount < totalRefunded) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Ensures payers and receivers are valid addresses among user1, user2, user4, user5 only.
     */
    function echidna_valid_payer_and_receiver() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            bool validPayer    = (payment.payer == user1 || payment.payer == user5);
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

            // If not released, the escrow is still holding payment.amount - payment.amountRefunded
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

            // If amountRefunded == payment.amount, then it's fully refunded. 
            // That payment must not also be 'released'.
            if (payment.amountRefunded == payment.amount && payment.released) {
                return false;
            }
        }
        return true;
    }
}
