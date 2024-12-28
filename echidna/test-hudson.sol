// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/SecurityContext.sol";
import "../src/SystemSettings.sol";
import "../src/inc/utils/Hevm.sol";

contract test_hudson {
    address constant admin = address(0x00001);
    address constant user3 = address(0x30000); // Deployer

    address constant user1 = address(0x10000); // Payer1
    address constant user2 = address(0x20000); // Receiver1
    address constant user4 = address(0x40000); // Receiver2
    address constant user5 = address(0x50000); // Payer2
    address constant userDeadbeef = address(0xDeaDBeef);
    address constant vault = address(0x50000);

    PaymentEscrow escrow;
    SecurityContext securityContext;
    SystemSettings systemSettings;

    uint256 call_count = 0;
    bool first_call = false;
    bool first_call_released = false;

    bool payment_success = false;
    bool release_success = false;
    bool refund_success = false;

    constructor() payable {
        require(msg.value > 0, "Initial balance required");
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings, false);
    }

    function placePayment1(uint256 amount, bool randomizePayer, bool randomizeReceiver) public {
            // Only proceed if we have enough balance
            if (amount > address(this).balance) {
                return;
            }

            // Use the bool `randomize` to determine payer and receiver
            address payer = randomizePayer ? user1 : user5;
            address receiver = randomizeReceiver ? user2 : user4;

            // Generate the paymentId
            bytes32 paymentId = keccak256(abi.encodePacked(call_count, address(this)));

            PaymentInput memory input = PaymentInput(address(0), paymentId, receiver, payer, amount);

            require(address(payer).balance >= amount, "Payer does not have enough balance");

            // Simulate payer placing the payment
            hevm.prank(payer);
            (bool success, ) = address(escrow).call{value: amount}(
                abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
            );

            payment_success = success;
            if (success) {
                call_count++;
            }
        }

    function releaseEscrow1(uint256 i) public {
        if (i < call_count) {
            first_call_released = true;

            // Generate paymentId
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));

            // Release the escrow using msg.sender
            hevm.prank(msg.sender);
            (bool success, ) = address(escrow).call(
                abi.encodeWithSignature("releaseEscrow(bytes32)", paymentId)
            );

            release_success = success;
        }
    }

    function refundPayment1(uint256 i, uint256 amount) public {
        if (i < call_count) {
            // Generate paymentId
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));

            // Refund the payment using msg.sender
            hevm.prank(msg.sender);
            (bool success, ) = address(escrow).call(
                abi.encodeWithSignature("refundPayment(bytes32,uint256)", paymentId, amount)
            );

            refund_success = success;
        }
    }

    // Invariant: No zero payment amount
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

    // Invariant: No incorrectly released payments
    function echidna_no_incorrectly_released_payments() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);
            if (payment.released) {
                if (!(payment.payerReleased && payment.receiverReleased)) {
                    return false;
                }
            }
        }
        return true;
    }

    // Invariant: Escrow funds sufficient to cover refunds
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

    // Invariant: Escrow balance sufficient to cover locked funds. checks to see if escrow drained 
    function echidna_escrow_balance_sufficient() public view returns (bool) {
        uint256 totalLocked = 0;

        // Sum up amounts that are still locked for all payments
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            // If payment not fully released add to total locked
            if (!payment.released) {
                totalLocked += (payment.amount - payment.amountRefunded);
            }
        }
        // Compare escrow actual balance with total still locked
        return address(escrow).balance >= totalLocked;
    }

    //invariant: no excess refund for each payment
    function echidna_no_excess_refund_for_each_payment() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            // if payment exists ensure the refunded portion never exceeds its original amount
            if (payment.amountRefunded > payment.amount) {
                return false;
            }
        }
        return true;
    }

    // invariant: no payment is both fully refunded and released
    function echidna_no_fully_refunded_and_released_payment() public view returns (bool) {
        for (uint256 i = 0; i < call_count; i++) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));
            Payment memory payment = escrow.getPayment(paymentId);

            // if fully refunded shouldnt also mark it as released
            if (payment.amountRefunded == payment.amount && payment.released) {
                return false;
            }
        }
        return true;
    }

}
