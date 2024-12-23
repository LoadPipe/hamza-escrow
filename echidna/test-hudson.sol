// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/SecurityContext.sol";
import "../src/SystemSettings.sol";
import "../node_modules/@crytic/properties/contracts/util/Hevm.sol";

contract test_hudson {
    address constant admin = address(0x00001);
    address constant user1 = address(0x10000); // Payer
    address constant user2 = address(0x20000); // Receiver
    address constant user3 = address(0x30000);
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
        escrow = new PaymentEscrow(securityContext, systemSettings);
    }

    function placePayment1(uint256 amount) public {
        // Only proceed if we have enough balance
        if (amount > address(this).balance) {
            return;
        }

        first_call = true;

        // Generate the paymentId
        bytes32 paymentId = keccak256(abi.encodePacked(call_count, address(this)));

        // Set user1 as the payer and user2 as the receiver
        PaymentInput memory input = PaymentInput(address(0), paymentId, user2, user1, amount);

        // Simulate user1 placing the payment
        hevm.prank(user1);
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
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));

            // Randomly select whether the payer or receiver should attempt to release the escrow
            address releaser = (block.timestamp % 2 == 0) ? user1 : user2;

            // Use hevm.prank to set the msg.sender for the releaseEscrow call
            hevm.prank(releaser);
            (bool success, ) = address(escrow).call(
                abi.encodeWithSignature("releaseEscrow(bytes32)", paymentId)
            );
            release_success = success;
        }
    }

    function refundPayment1(uint256 i, uint256 amount) public {
        if (i < call_count) {
            bytes32 paymentId = keccak256(abi.encodePacked(i, address(this)));

            hevm.prank(user2); // Receiver initiates the refund
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

    // payment release success invariant
    function echidna_payment_released_success() public view returns (bool) {
        if (first_call_released) {
            return release_success;
        }
        return true;
    }

    // inariant: escrow funds sufficient to cover refunds
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

}
