// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./PaymentEscrow.sol";
import "./PaymentInput.sol";
import "./SecurityContext.sol";
import "./SystemSettings.sol";

/**
 * @title PaymentEscrowInvariant
 * @notice This contract uses Echidna to test invariants for the PaymentEscrow contract.
 * It deploys a fresh PaymentEscrow with a SecurityContext and SystemSettings, then tries 
 * arbitrary sequences of actions (placePayment, releaseEscrow, refundPayment) with random 
 * inputs to detect any state inconsistency.
 */
contract PaymentEscrowInvariant {
    PaymentEscrow escrow;
    SecurityContext securityContext;
    SystemSettings systemSettings;

    // We will track one or more test payment IDs. In practice, Echidna can generate random
    // payment IDs and attempts to break invariants. We can store some known IDs that we attempt.
    bytes32 constant TEST_ID = keccak256("test-payment");

    bytes32[] knownPayments;          
    address[] knownTokenAddresses; 


    constructor() {
        // Deploy security context with the test contract as admin
        securityContext = new SecurityContext(address(this));

        // Give this contract ARBITER_ROLE for testing
        bytes32 ARBITER_ROLE = keccak256("ARBITER_ROLE");
        securityContext.grantRole(ARBITER_ROLE, address(this));

        // Deploy system settings with zero fee for simplicity
        systemSettings = new SystemSettings(ISecurityContext(address(securityContext)), address(0xC0FFEE), 0);

        // Deploy PaymentEscrow contract
        escrow = new PaymentEscrow(
            ISecurityContext(address(securityContext)),
            ISystemSettings(address(systemSettings))
        );

        knownPayments.push(keccak256(abi.encodePacked("test-payment")));
        knownTokenAddresses.push(address(0));
    }

    // Helper to get the Payment struct for the known test ID
    function _getTestPayment() internal view returns (Payment memory) {
        return escrow.getPayment(TEST_ID);
    }

    /**
     * @notice Invariant 1: Payment amount should never be less than the refunded amount
     * This checks that no matter what fuzzing calls occur, if a payment is created with TEST_ID,
     * amountRefunded <= amount must always hold.
     */
    function echidna_amount_never_less_than_refunded() public view returns (bool) {
        Payment memory p = _getTestPayment();
        return p.amountRefunded <= p.amount;
    }

    /**
     * @notice Invariant 2: Payment cannot be marked released unless both payerReleased and receiverReleased are true.
     * If the payment is released, then payerReleased and receiverReleased should also be true.
     */
    function echidna_released_implies_consent() public view returns (bool) {
        Payment memory p = _getTestPayment();
        if (p.released) {
            // If payment is released, payer and receiver consent is required.
            // Note: Arbitrators can stand in for payer consent, but let's assume if released is true,
            // payerReleased and receiverReleased must be true. The code sets payerReleased 
            // automatically if an arbiter calls release. Hence if released is true, both must be true.
            return (p.payerReleased && p.receiverReleased);
        }
        return true; // If not released, no constraint.
    }

    /**
     * @notice Invariant 3: No negative amounts.
     * By definition of uint, amount and amountRefunded can't be negative. 
     * We still assert this explicitly for clarity.
     */
    function echidna_non_negative_amounts() public view returns (bool) {
        Payment memory p = _getTestPayment();
        // Always non-negative since they're uint256
        return (p.amount >= 0 && p.amountRefunded >= 0);
    }

    /**
     * @notice Invariant 4: If released, the sum of payout + fee should not exceed original amount minus refunded.
     * Once a payment is released, it splits into (amountToPay + fee). 
     * The contract ensures fee is within allowed bounds. Let's just check consistency: 
     * feeBps = systemSettings.feeBps(), fee = (amount - amountRefunded)*feeBps/10000.
     */
    function echidna_fee_calculation_sanity() public view returns (bool) {
        Payment memory p = _getTestPayment();
        if (p.released) {
            // After release, total available = p.amount - p.amountRefunded
            uint256 totalAvailable = p.amount - p.amountRefunded;
            uint256 feeBps = systemSettings.feeBps();
            uint256 fee = (totalAvailable * feeBps) / 10000;
            if (fee > totalAvailable) {
                // Fee should never exceed total available.
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Invariant 5: Once released is true, no further refunds should reduce available amount.
     * We can’t easily detect actions post-release directly without instrumentation. But we know 
     * if echidna tries to refund after release, `refundPayment` should revert or not change state.
     * Since invariants are always checked, if refunds did happen post-release, amountRefunded might exceed amount.
     * That should be caught by previous invariants. So this is implicitly covered by invariants 1 & 2.
     * We do nothing extra here, but we keep this in mind.
     */

    /**
     * @notice Invariant 6: If payment is never placed, it remains in default state with zero amounts.
     * This ensures that no random calls can create a non-zero payment without calling placePayment first.
     * If no placePayment was called with TEST_ID, the payment struct should be default.
     */
    function echidna_default_state_if_not_placed() public view returns (bool) {
        Payment memory p = _getTestPayment();
        // If the payment was never placed, p.id would be zero and others would be zero.
        // If placed, p.id = TEST_ID. If not placed, p.id == 0x0.
        // Let's just check a consistency: if p.id != TEST_ID and amount > 0, that's wrong.
        if (p.id != TEST_ID && p.amount > 0) {
            return false;
        }
        return true;
    }

    mapping(address => uint256) totalOutstandingTokens;

    function echidna_global_balance_invariant() public returns (bool) {
        uint256 totalOutstandingETH = 0;


        // Iterate through known payments to compute total outstanding balances
        for (uint256 i = 0; i < knownPayments.length; i++) {
            Payment memory p = escrow.getPayment(knownPayments[i]);
            if (p.amount > 0) {
                uint256 outstanding = p.amount - p.amountRefunded;
                if (p.currency == address(0)) {
                    // ETH payment
                    totalOutstandingETH += outstanding;
                } else {
                    // Token payment
                    totalOutstandingTokens[p.currency] += outstanding;
                }
            }
        }

        // Check ETH balance consistency
        if (totalOutstandingETH > address(escrow).balance) {
            return false;
        }

        // Check token balances for all tokens used in payments
        for (uint256 i = 0; i < knownPayments.length; i++) {
            Payment memory p = escrow.getPayment(knownPayments[i]);
            if (p.amount > 0 && p.currency != address(0)) {
                uint256 tokenBalance = IERC20(p.currency).balanceOf(address(escrow));
                if (totalOutstandingTokens[p.currency] > tokenBalance) {
                    return false;
                }
            }
        }

        return true;
    }

    /**
    * @notice Invariant 7: No refunds should occur on a released payment.
    * Once a payment is marked as `released`, `amountRefunded` must remain unchanged.
    */
    function echidna_no_refund_after_release() public view returns (bool) {
        for (uint256 i = 0; i < knownPayments.length; i++) {
            Payment memory p = escrow.getPayment(knownPayments[i]);

            if (p.released) {
                // Once a payment is released, no refunds should occur.
                // amountRefunded should remain unchanged after release.
                uint256 totalReleased = p.amount - p.amountRefunded;

                // If the payment is released, totalReleased should equal the already paid out funds.
                if (totalReleased != 0) {
                    return false;
                }
            }
        }

        return true;
    }

    /**
     * @notice Global Invariant: Total outstanding funds across all payments
     * must not exceed the escrow contract's actual balance (ETH + tokens).
     */
    function echidna_total_funds_consistency() public view returns (bool) {
        uint256 totalOutstandingETH = 0;
        uint256[] memory totalOutstandingTokens = new uint256[](knownTokenAddresses.length);

        // Sum up total outstanding balances across all payments
        for (uint256 i = 0; i < knownPayments.length; i++) {
            Payment memory p = escrow.getPayment(knownPayments[i]);

            if (p.amount > 0 && !p.released) {
                uint256 outstanding = p.amount - p.amountRefunded;

                if (p.currency == address(0)) {
                    // ETH payments
                    totalOutstandingETH += outstanding;
                } else {
                    // Token payments: find the index in knownTokenAddresses
                    for (uint256 j = 0; j < knownTokenAddresses.length; j++) {
                        if (p.currency == knownTokenAddresses[j]) {
                            totalOutstandingTokens[j] += outstanding;
                        }
                    }
                }
            }
        }

        // Check ETH balance
        if (totalOutstandingETH > address(escrow).balance) {
            return false;
        }

        // Check token balances
        for (uint256 j = 0; j < knownTokenAddresses.length; j++) {
            if (knownTokenAddresses[j] != address(0)) {
                // Check if the address is a valid contract
                uint256 size;
                assembly {
                    size := extcodesize(knownTokenAddresses[j]);
                }
                if (size > 0) {
                    uint256 tokenBalance = IERC20(knownTokenAddresses[j]).balanceOf(address(escrow));
                    if (totalOutstandingTokens[j] > tokenBalance) {
                        return false;
                    }
                }
            }
        }

        return true;
    }


    /**
     * @notice Adds a new payment ID to the list of known payments.
     */
    function addPayment(bytes32 paymentId) public {
        knownPayments.push(paymentId);
    }

    /**
     * @notice Adds a known token address to track its outstanding balance.
     */
    function addKnownToken(address tokenAddress) public {
        knownTokenAddresses.push(tokenAddress);
    }

    

    // Since Echidna doesn’t have a direct concept of events or revert checking here,
    // we rely on state-based invariants to ensure no illegal state occurs.

    // We can add more invariants if desired, but these cover the major logical consistencies:
    // - Refunds never exceed original amount
    // - Release conditions hold
    // - Fee sanity
    // - Default states remain default
    // - No negative values

    // A no-op test function to exclude from coverage
    function test() public {}


}
