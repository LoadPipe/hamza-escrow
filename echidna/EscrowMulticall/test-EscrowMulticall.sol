// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../src/PaymentEscrow.sol";
import "../../src/EscrowMulticall.sol";
import "../../src/SecurityContext.sol";
import "../../src/SystemSettings.sol";
import "../../src/inc/utils/Hevm.sol";


contract test_EscrowMulticallInvariants {
    address constant admin = address(0x00001);
    address constant user3 = address(0x30000); // Deployer

    address constant user1 = address(0x10000); // Payer1
    address constant user2 = address(0x20000); // Receiver1
    address constant user4 = address(0x40000); // Receiver2
    address constant user5 = address(0x50000); // Payer2
    address constant userDeadbeef = address(0xDeaDBeef);
    address constant vault = address(0x99999);


    EscrowMulticall public multi;
    SecurityContext public securityContext;
    SystemSettings public systemSettings;

    PaymentEscrow[] public escrows;


    struct PaymentRecord {
        PaymentEscrow escrow; 
        bytes32 paymentId;
    }

    // All payments made via multipay
    PaymentRecord[] public allPayments;

    // Payment success/failure indicators
    bool public payment_success = false;
    bool public release_success = false;
    bool public refund_success = false;


    constructor() payable {
        require(msg.value > 0, "Initial balance required");

        // Set up security & system settings
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);

        // Create multiple PaymentEscrow instances
        for (uint256 i = 0; i < 3; i++) {
            PaymentEscrow e = new PaymentEscrow(securityContext, systemSettings, false);
            escrows.push(e);
        }

        // Create the multicall wrapper
        multi = new EscrowMulticall();
    }

    function multiPay1(
        uint256 amount, 
        bool randomizePayer, 
        bool randomizeReceiver, 
        uint256 escrowIndex
    )
        public
    {
        // Avoid out of bounds index
        if (escrowIndex >= escrows.length) return;

        // Only proceed if enough balance to cover the amount
        if (amount > address(this).balance) {
            return;
        }

        // Choose payer receiver
        address payer = randomizePayer ? user1 : user5;
        address receiver = randomizeReceiver ? user2 : user4;

        PaymentEscrow target = escrows[escrowIndex];

        // Build array for multipay
        MulticallPaymentInput[] memory inputs = new MulticallPaymentInput[](1);

        // Generate the paymentId
        bytes32 paymentId = keccak256(
            abi.encodePacked(
                allPayments.length, 
                address(this),
                escrowIndex
            )
        );

        // Populate the single payment input
        inputs[0] = MulticallPaymentInput({
            contractAddress: address(target),
            currency: address(0), // native
            id: paymentId,
            receiver: receiver,
            payer: payer,
            amount: amount
        });

        // payer call multipay
        hevm.prank(payer);
        (bool success, ) = address(multi).call{value: amount}(
            abi.encodeWithSignature("multipay((address,address,bytes32,address,address,uint256)[])", inputs)
        );

        payment_success = success;

        if (success) {
            // Record the new payment in our local list
            allPayments.push(
                PaymentRecord({
                    escrow: target,
                    paymentId: paymentId
                })
            );
        }
    }


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

    /// Invariant: No payment has zero amount
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

    /// Invariant: No incorrectly released payments 
    function echidna_no_incorrectly_released_payments() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);
            if (paymentData.released) {
                if (!(paymentData.payerReleased && paymentData.receiverReleased)) {
                    return false;
                }
            }
        }
        return true;
    }

    /// Invariant: Total refunded never exceeds total deposited for each payment
    function echidna_escrow_funds_sufficient_per_payment() public view returns (bool) {
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);
            // If the sum refunded for this payment is bigger than the payment amount its invalid
            if (paymentData.amountRefunded > paymentData.amount) {
                return false;
            }
        }
        return true;
    }

    /// Invariant: Payer must be either user1 or user5. Receiver must be user2 or user4
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

    /// Invariant: For each payment if it's not released the escrows balance must cover it
    function echidna_escrow_balance_sufficient_for_locked_funds() public view returns (bool) {
        uint256[] memory lockedBalances = new uint256[](escrows.length);

        // Sum locked amounts for each payment in its corresponding escrow
        for (uint256 i = 0; i < allPayments.length; i++) {
            PaymentRecord memory record = allPayments[i];
            Payment memory paymentData = record.escrow.getPayment(record.paymentId);

            if (!paymentData.released) {
                // Find the index of this escrow in the escrows array
                for (uint256 j = 0; j < escrows.length; j++) {
                    if (address(escrows[j]) == address(record.escrow)) {
                        // Add the locked portion of the payment
                        lockedBalances[j] += (paymentData.amount - paymentData.amountRefunded);
                        break;
                    }
                }
            }
        }

        // Verify each escrows balance covers its total locked amount
        for (uint256 i = 0; i < escrows.length; i++) {
            if (address(escrows[i]).balance < lockedBalances[i]) {
                return false;
            }
        }
        return true;
    }


    /// Invariant: A payment cannot be both fully refunded and released
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
