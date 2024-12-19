// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/IEscrowContract.sol";
import "../src/PaymentInput.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./helpers/MockSystemSettings.sol";
import "./helpers/MockToken.sol";
import "./helpers/MockSecurityContext.sol";

/**
 * @title PaymentEscrowTest
 *
 * Echidna test contract for the PaymentEscrow functionality.
 */
contract PaymentEscrowTest is PaymentEscrow {
    IERC20 private token;

    // Track all payment IDs for validation
    bytes32[] public paymentIds;

    constructor() PaymentEscrow(new MockSecurityContext(new bytes32[](0), new address[](0)), new MockSystemSettings(address(0), 100)) {
        token = new MockToken();

        MockToken(address(token)).mint(address(this), 10_000 * 1e18);
    }

    // Fuzz function to create payments
    function fuzz_placePayment(bytes32 paymentId, uint256 amount) public {
        
        if (amount > 0 && paymentId != bytes32(0)) {
            
            PaymentInput memory paymentInput = PaymentInput({
                id: paymentId,
                payer: msg.sender,
                receiver: address(this),
                currency: address(token),
                amount: 100
            });

            // Call the placePayment function via an external interface call
            IEscrowContract(address(this)).placePayment{value: (address(token) == address(0) ? amount : 0)}(paymentInput);

            // Track payment ID for invariant checks
            paymentIds.push(paymentId);
        }
    }

    // Invariant: Deliberately fails to verify Echidna's detection of failures
    function echidna_alwaysFails() public pure returns (bool) {
        return false; // Always fails to confirm Echidna setup works
    }

    // Invariant: No payment should have an amount of 100
    function echidna_no100AmountPayments() public view returns (bool) {
        for (uint256 i = 0; i < paymentIds.length; i++) {
            Payment memory payment = getPayment(paymentIds[i]);
            if (payment.amount == 100) {
                return false; // Fail if any payment has 100 amount
            }
        }
        return true; 
    }

    // Additional invariant: Payment IDs should not duplicate
    function echidna_noDuplicatePaymentIds() public view returns (bool) {
        for (uint256 i = 0; i < paymentIds.length; i++) {
            for (uint256 j = i + 1; j < paymentIds.length; j++) {
                if (paymentIds[i] == paymentIds[j]) {
                    return false; // Fail if duplicate IDs are found
                }
            }
        }
        return true; // Pass if all IDs are unique
    }
}
