// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/PaymentInput.sol";
import "./helpers/MockSecurityContext.sol";
import "./helpers/MockSystemSettings.sol";
import "@crytic/properties/contracts/util/Hevm.sol";

/// @title Echidna Test with hevm.prank

contract PaymentEscrowTest {

    PaymentEscrow paymentEscrow;

    bytes32 constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

    // Actual EOA-like addresses for payers and receivers
    address[] payers = [
        address(0x1001),
        address(0x1002),
        address(0x1003)
    ];

    address[] receivers = [
        address(0x2001),
        address(0x2002),
        address(0x2003)
    ];

    uint256 constant INITIAL_BAL = 100 ether;

    mapping(address => uint256) public balances;
    uint256 public escrowBalance;

    struct PaymentInfo {
        bool exists;
        bool fullyReleased;
        address payer;
        address receiver;
        uint256 initialAmount;
        uint256 amountRefunded;
    }

    mapping(bytes32 => PaymentInfo) public paymentRecords;
    mapping(address => bool) public payerHadReleasedPayment;

    uint256 internal idCounter;

    constructor() {
        // Setup
        MockSecurityContext security = new MockSecurityContext(new bytes32[](0), new address[](0));
        MockSystemSettings settings = new MockSystemSettings(address(0), 100); // fee = 1%
        paymentEscrow = new PaymentEscrow(security, settings);
        security.grantRole(ARBITER_ROLE, address(this));

        // Initialize balances
        for (uint i = 0; i < payers.length; i++) {
            balances[payers[i]] = INITIAL_BAL;
        }
        for (uint j = 0; j < receivers.length; j++) {
            balances[receivers[j]] = INITIAL_BAL;
        }
    }

    function _newPaymentId() internal returns (bytes32) {
        idCounter++;
        return keccak256(abi.encodePacked(address(this), idCounter));
    }

    function getRandomPayer(uint256 x) internal view returns (address) {
        return payers[x % payers.length];
    }

    function getRandomReceiver(uint256 x) internal view returns (address) {
        return receivers[x % receivers.length];
    }

    // Place a payment. This is always called by the test contract.
    function placeRandomPayment(uint256 payerIndex, uint256 receiverIndex, uint256 amt) public {
        address payer = getRandomPayer(payerIndex);
        address receiver = getRandomReceiver(receiverIndex);
        uint256 amount = (amt % 10 ether) + 1;

        if (balances[payer] < amount) return;

        bytes32 paymentId = _newPaymentId();
        PaymentInput memory input = PaymentInput({
            id: paymentId,
            payer: payer,
            receiver: receiver,
            currency: address(0),
            amount: amount
        });

        try paymentEscrow.placePayment{value: amount}(input) {
            balances[payer] -= amount;
            escrowBalance += amount;
            paymentRecords[paymentId] = PaymentInfo({
                exists: true,
                fullyReleased: false,
                payer: payer,
                receiver: receiver,
                initialAmount: amount,
                amountRefunded: 0
            });
        } catch {
            // no change if fail
        }
    }

    // Attempt to release payment as payer, receiver, or arbiter.
    // We pick a role randomly: if role = 0 (payer), 1 (receiver), else arbiter.
    function tryReleasePayment(bytes32 paymentId, uint8 role) public {
        if (!paymentRecords[paymentId].exists) return;
        PaymentInfo memory beforeLocal = paymentRecords[paymentId];
        Payment memory beforeOnChain = paymentEscrow.getPayment(paymentId);
        if (beforeOnChain.amount == 0) return;

        address caller;
        if (role == 0) {
            // payer
            caller = beforeLocal.payer;
        } else if (role == 1) {
            // receiver
            caller = beforeLocal.receiver;
        } else {
            // arbiter (this contract)
            caller = address(this);
        }

        hevm.prank(caller);
        try paymentEscrow.releaseEscrow(paymentId) {
            Payment memory afterOnChain = paymentEscrow.getPayment(paymentId);
            if (!beforeLocal.fullyReleased && afterOnChain.released) {
                uint256 totalToRelease = beforeOnChain.amount - beforeOnChain.amountRefunded;
                uint256 feeBps = 100; // from settings
                uint256 fee = (totalToRelease * feeBps) / 10000;
                uint256 receiverGets = totalToRelease - fee;

                escrowBalance -= totalToRelease;
                balances[afterOnChain.receiver] += receiverGets;

                paymentRecords[paymentId].fullyReleased = true;
                payerHadReleasedPayment[beforeLocal.payer] = true;
            }
        } catch {
            // no change
        }
    }

    // Attempt a refund as either receiver or arbiter (this contract).
    // role = 1 for receiver, anything else for arbiter.
    function tryRefundPayment(bytes32 paymentId, uint256 refundAmount, uint8 role) public {
        if (!paymentRecords[paymentId].exists) return;
        Payment memory beforeOnChain = paymentEscrow.getPayment(paymentId);
        if (beforeOnChain.amount == 0) return;

        PaymentInfo memory beforeLocal = paymentRecords[paymentId];

        address caller;
        if (role == 1) {
            caller = beforeLocal.receiver; // receiver
        } else {
            caller = address(this); // arbiter
        }

        refundAmount = refundAmount % (beforeOnChain.amount + 1);

        hevm.prank(caller);
        try paymentEscrow.refundPayment(paymentId, refundAmount) {
            Payment memory afterOnChain = paymentEscrow.getPayment(paymentId);
            if (afterOnChain.amountRefunded > beforeOnChain.amountRefunded) {
                uint256 actuallyRefunded = afterOnChain.amountRefunded - beforeOnChain.amountRefunded;
                escrowBalance -= actuallyRefunded;
                balances[afterOnChain.payer] += actuallyRefunded;
                paymentRecords[paymentId].amountRefunded = afterOnChain.amountRefunded;
            }
        } catch {
            // no change
        }
    }

    // The invariant:
    // After a payment is fully released, that payer's balance should not exceed INITIAL_BAL.
    function echidna_payer_never_profits_after_release() public returns (bool) {
        for (uint i = 0; i < payers.length; i++) {
            address p = payers[i];
            if (payerHadReleasedPayment[p]) {
                if (balances[p] > INITIAL_BAL) {
                    return false;
                }
            }
        }
        return true;
    }
}
