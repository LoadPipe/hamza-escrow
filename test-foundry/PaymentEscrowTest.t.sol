// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {PaymentEscrow, IEscrowContract} from "../src/PaymentEscrow.sol";
import {SecurityContext} from "../src/SecurityContext.sol";
import {SystemSettings} from "../src/SystemSettings.sol";
import {TestToken} from "../src/TestToken.sol";
import {ISecurityContext} from "../src/ISecurityContext.sol";
import {ISystemSettings} from "../src/ISystemSettings.sol";
import {PaymentInput, Payment} from "../src/PaymentInput.sol";
import {console} from "forge-std/console.sol";
import {FailingToken} from "../src/FailingToken.sol";

contract PaymentEscrowTest is Test {
    SecurityContext internal securityContext;
    PaymentEscrow internal escrow;
    TestToken internal testToken;
    SystemSettings internal systemSettings;

    address internal admin;
    address internal nonOwner;
    address internal payer1;
    address internal payer2;
    address internal receiver1;
    address internal receiver2;
    address internal vaultAddress;
    address internal arbiter;
    address internal dao;

    bytes32 internal constant ARBITER_ROLE =
        0xbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae;
    bytes32 internal constant DAO_ROLE =
        0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603;

    function setUp() public {
        admin = address(1);
        nonOwner = address(2);
        vaultAddress = address(3);
        payer1 = address(4);
        payer2 = address(5);
        receiver1 = address(6);
        receiver2 = address(7);
        arbiter = address(8);
        dao = address(9);

        vm.deal(admin, 100 ether);
        vm.deal(nonOwner, 100 ether);
        vm.deal(payer1, 100 ether);
        vm.deal(payer2, 100 ether);
        vm.deal(receiver1, 100 ether);
        vm.deal(receiver2, 100 ether);

        vm.startPrank(admin);
        securityContext = new SecurityContext(admin);
        testToken = new TestToken("XYZ", "ZYX");
        systemSettings = new SystemSettings(ISecurityContext(address(securityContext)), vaultAddress, 0);

        escrow = new PaymentEscrow(ISecurityContext(address(securityContext)), ISystemSettings(address(systemSettings)));

        securityContext.grantRole(ARBITER_ROLE, vaultAddress);
        securityContext.grantRole(ARBITER_ROLE, arbiter);
        securityContext.grantRole(DAO_ROLE, dao);

        testToken.mint(nonOwner, 10_000_000_000);
        testToken.mint(payer1, 10_000_000_000);
        testToken.mint(payer2, 10_000_000_000);
        vm.stopPrank();
    }

    function _getBalance(address who, bool isToken) internal view returns (uint256) {
        return isToken ? testToken.balanceOf(who) : who.balance;
    }

    function _placePayment(
        bytes32 paymentId,
        address payerAccount,
        address receiverAddress,
        uint256 amount,
        bool isToken
    ) internal {
        PaymentInput memory req = PaymentInput({
            currency: isToken ? address(testToken) : address(0),
            id: paymentId,
            receiver: receiverAddress,
            payer: payerAccount,
            amount: amount
        });

        if (isToken) {
            vm.prank(payerAccount);
            testToken.approve(address(escrow), amount);
            vm.prank(payerAccount);
            escrow.placePayment(req);
        } else {
            vm.prank(payerAccount);
            escrow.placePayment{value: amount}(req);
        }
    }

    function _getPayment(bytes32 paymentId) internal view returns (Payment memory) {
        return escrow.getPayment(paymentId);
    }

    function _verifyPayment(
        Payment memory actual,
        Payment memory expected
    ) internal {
        assertEq(actual.id, expected.id);
        assertEq(actual.payer, expected.payer);
        assertEq(actual.receiver, expected.receiver);
        assertEq(actual.amount, expected.amount);
        assertEq(actual.amountRefunded, expected.amountRefunded);
        assertEq(actual.currency, expected.currency);
        assertEq(actual.payerReleased, expected.payerReleased);
        assertEq(actual.receiverReleased, expected.receiverReleased);
        assertEq(actual.released, expected.released);
    }

    // balances helper function for testing
    function _recordBalances() internal view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](5);
        balances[0] = address(escrow).balance; // Escrow balance
        balances[1] = _getBalance(receiver1, false); // Receiver1 balance
        balances[2] = _getBalance(payer1, false); // Payer1 balance
        balances[3] = _getBalance(receiver2, false); // Receiver2 balance
        balances[4] = _getBalance(payer2, false); // Payer2 balance
        return balances;
    }


    // Deployment
    function testDeploymentArbiterRole() public {
        bool hasArbiterArbiter = securityContext.hasRole(ARBITER_ROLE, arbiter);
        bool hasNonOwnerArbiter = securityContext.hasRole(ARBITER_ROLE, nonOwner);
        bool hasVaultArbiter = securityContext.hasRole(ARBITER_ROLE, vaultAddress);

        assertTrue(hasArbiterArbiter);
        assertFalse(hasNonOwnerArbiter);
        assertTrue(hasVaultArbiter);
    }

    // Place Payments
    function testCanPlaceSingleNativePayment() public {
        uint256 initialContractBalance = _getBalance(address(escrow), false);
        uint256 initialPayerBalance = _getBalance(payer1, false);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        Payment memory payment = _getPayment(paymentId);

        _verifyPayment(
            payment,
            Payment({
                id: paymentId,
                payer: payer1,
                receiver: receiver1,
                amount: amount,
                amountRefunded: 0,
                payerReleased: false,
                receiverReleased: false,
                released: false,
                currency: address(0)
            })
        );

        uint256 newContractBalance = _getBalance(address(escrow), false);
        uint256 newPayerBalance = _getBalance(payer1, false);

        // amount leaves payer
        assertTrue(newPayerBalance <= (initialPayerBalance - amount));

        // amount accrues in contract
        assertEq(newContractBalance, initialContractBalance + amount);
    }

    function testCanPlaceSingleTokenPayment() public {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 initialPayerBalance = _getBalance(payer1, true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        Payment memory payment = _getPayment(paymentId);

        _verifyPayment(
            payment,
            Payment({
                id: paymentId,
                payer: payer1,
                receiver: receiver1,
                amount: amount,
                amountRefunded: 0,
                payerReleased: false,
                receiverReleased: false,
                released: false,
                currency: address(testToken)
            })
        );

        uint256 newContractBalance = _getBalance(address(escrow), true);
        uint256 newPayerBalance = _getBalance(payer1, true);

        assertTrue(newPayerBalance <= (initialPayerBalance - amount));
        assertEq(newContractBalance, initialContractBalance + amount);
    }

    function testCannotPlaceOrderWithDuplicateId() public {
        uint256 amount = 10_000_000;
        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        vm.expectRevert("DuplicatePayment");
        _placePayment(paymentId, payer1, receiver1, amount, false);
    }

    function testPaidTokenAmountsAccrueInContract() public {
        uint256 amount1 = 10_000_000;
        uint256 amount2 = 20_000_000;
        uint256 amount3 = 30_000_000;

        bytes32 paymentId1 = keccak256("0x01");
        bytes32 paymentId2 = keccak256("0x02");
        bytes32 paymentId3 = keccak256("0x03");

        // Approve enough once and place two payments
        vm.startPrank(payer1);
        testToken.approve(address(escrow), amount1 + amount2);
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId1,
                receiver: receiver1,
                payer: payer1,
                amount: amount1
            })
        );
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId2,
                receiver: receiver1,
                payer: payer1,
                amount: amount2
            })
        );
        vm.stopPrank();

        assertEq(_getBalance(address(escrow), true), amount1 + amount2);

        _placePayment(paymentId3, payer2, receiver2, amount3, true);
        assertEq(_getBalance(address(escrow), true), amount1 + amount2 + amount3);
    }

    function testPaidNativeAmountsAccrueInContract() public {
        uint256 amount1 = 10_000_000;
        uint256 amount2 = 20_000_000;
        uint256 amount3 = 30_000_000;

        bytes32 paymentId1 = keccak256("0x01");
        bytes32 paymentId2 = keccak256("0x02");
        bytes32 paymentId3 = keccak256("0x03");

        _placePayment(paymentId1, payer1, receiver1, amount1, false);
        _placePayment(paymentId2, payer2, receiver1, amount2, false);

        assertEq(_getBalance(address(escrow), false), amount1 + amount2);

        _placePayment(paymentId3, payer2, receiver2, amount3, false);

        assertEq(_getBalance(address(escrow), false), amount1 + amount2 + amount3);
    }

    function testCannotPlaceOrderWithoutCorrectNativeAmount() public {
        uint256 amount = 10_000_000;
        bytes32 paymentId = keccak256("0x01");

        vm.prank(payer1);
        vm.expectRevert("InsufficientAmount");
        escrow.placePayment{value: amount - 1}(
            PaymentInput({
                currency: address(0),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
    }

    function testCannotPlaceOrderWithoutCorrectTokenApproval() public {
        uint256 amount = 10_000_000;
        bytes32 paymentId = keccak256("0x01");

        vm.startPrank(payer1);
        testToken.approve(address(escrow), amount - 1);
        vm.expectRevert();
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
        vm.stopPrank();
    }

    function testCannotPlaceOrderWithoutSufficientTokenBalance() public {
        uint256 amount = 10_000_000;
        bytes32 paymentId = keccak256("0x01");

        // transfer all payer1 tokens away
        vm.startPrank(payer1);
        testToken.transfer(payer2, testToken.balanceOf(payer1));
        testToken.approve(address(escrow), amount);
        vm.expectRevert();
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
        vm.stopPrank();
    }

    // Release Payments
    function testCannotReleaseWithNoApprovals() public {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        uint256 newContractBalance = _getBalance(address(escrow), true);
        assertEq(newContractBalance, initialContractBalance + amount);

        // arbiter tries to release - counts as payer release
        vm.prank(arbiter);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: false,
            released: false,
            currency: address(testToken)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCannotReleaseWithOnlyPayerApproval() public {
        uint256 initialContractBalance = _getBalance(address(escrow), false);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        uint256 newContractBalance = _getBalance(address(escrow), false);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: false,
            released: false,
            currency: address(0)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), false);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCannotReleaseWithOnlyReceiverApproval() public {
        uint256 initialContractBalance = _getBalance(address(escrow), false);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        uint256 newContractBalance = _getBalance(address(escrow), false);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: false,
            receiverReleased: true,
            released: false,
            currency: address(0)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), false);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCanReleaseNativeWithBothApprovals() public {
        uint256 initialContractBalance = _getBalance(address(escrow), false);
        uint256 initialReceiverBalance = _getBalance(receiver1, false);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        uint256 newContractBalance = _getBalance(address(escrow), false);
        uint256 newReceiverBalance = _getBalance(receiver1, false);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: true,
            released: true,
            currency: address(0)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), false);
        uint256 finalReceiverBalance = _getBalance(receiver1, false);

        assertEq(finalReceiverBalance, (initialReceiverBalance + amount));
        assertEq(finalContractBalance, newContractBalance - amount);
    }

    function testCanReleaseTokenWithBothApprovals() public {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 initialReceiverBalance = _getBalance(receiver1, true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        uint256 newContractBalance = _getBalance(address(escrow), true);
        uint256 newReceiverBalance = _getBalance(receiver1, true);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: true,
            released: true,
            currency: address(testToken)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        uint256 finalReceiverBalance = _getBalance(receiver1, true);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertEq(finalReceiverBalance, newReceiverBalance + amount);
    }

    function testArbiterCanReleaseOnBehalfOfPayer() public {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 initialReceiverBalance = _getBalance(receiver1, true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        vm.startPrank(payer1);
        testToken.approve(address(escrow), amount);
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
        vm.stopPrank();

        uint256 newContractBalance = _getBalance(address(escrow), true);
        uint256 newReceiverBalance = _getBalance(receiver1, true);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.prank(arbiter);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: true,
            released: true,
            currency: address(testToken)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        uint256 finalReceiverBalance = _getBalance(receiver1, true);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertEq(finalReceiverBalance, newReceiverBalance + amount);
    }

    function testCannotReleasePaymentIfNotPartyOrArbiter() public {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        uint256 newContractBalance = _getBalance(address(escrow), true);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.prank(nonOwner);
        vm.expectRevert("Unauthorized");
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: false,
            receiverReleased: false,
            released: false,
            currency: address(testToken)
        }));

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCannotReleasePaymentTwice() public {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 initialReceiverBalance = _getBalance(receiver1, true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        uint256 newContractBalance = _getBalance(address(escrow), true);
        uint256 newReceiverBalance = _getBalance(receiver1, true);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: true,
            released: true,
            currency: address(testToken)
        }));

        // Try releasing again - should just have no effect
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        uint256 finalReceiverBalance = _getBalance(receiver1, true);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertEq(finalReceiverBalance, newReceiverBalance + amount);
    }

    function testMultiplePartialReleases() public {
        uint256 amount = 2 ether;
        bytes32 paymentId = keccak256("partial-releases-test");

        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Payer gives approval
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        // Verify state after payer approval
        Payment memory paymentAfterPayer = _getPayment(paymentId);
        assertTrue(paymentAfterPayer.payerReleased);
        assertFalse(paymentAfterPayer.receiverReleased);
        assertFalse(paymentAfterPayer.released);

        // Receiver gives approval
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        // Verify state after receiver approval
        Payment memory paymentAfterReceiver = _getPayment(paymentId);
        assertTrue(paymentAfterReceiver.payerReleased);
        assertTrue(paymentAfterReceiver.receiverReleased);
        assertTrue(paymentAfterReceiver.released);

        // Verify escrow funds were transferred
        uint256 finalEscrowBalance = address(escrow).balance;
        assertEq(finalEscrowBalance, 0);
    }

    // Refund Tests
    function _refundTest(
        uint256 amount,
        uint256 refundAmount,
        address _payer,
        address _receiver,
        address _refunder
    ) internal returns (bytes32) {
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 initialPayerBalance = _getBalance(_payer, true);

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, _payer, _receiver, amount, true);

        vm.prank(_refunder);
        escrow.refundPayment(paymentId, refundAmount);

        Payment memory payment = _getPayment(paymentId);
        assertEq(payment.amountRefunded, refundAmount);
        assertEq(payment.amount, amount);

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        uint256 finalPayerBalance = _getBalance(_payer, true);

        assertEq(finalContractBalance, initialContractBalance + (amount - refundAmount));
        assertEq(finalPayerBalance, initialPayerBalance - (amount - refundAmount));

        return paymentId;
    }

    function testArbiterCanPartialRefund() public {
        uint256 amount = 1_000_000;
        _refundTest(amount, amount / 5, payer1, receiver1, arbiter);
    }

    function testReceiverCanPartialRefund() public {
        uint256 amount = 1_000_000;
        _refundTest(amount, amount / 5, payer1, receiver1, receiver1);
    }

    function testArbiterCanFullRefund() public {
        uint256 amount = 1_000_000;
        _refundTest(amount, amount, payer1, receiver1, arbiter);
    }

    function testReceiverCanFullRefund() public {
        uint256 amount = 1_000_000;
        _refundTest(amount, amount, payer1, receiver1, receiver1);
    }

    function testMultiplePartialRefunds() public {
        uint256 amount = 1_000_000;
        uint256 refundAmount = amount / 5;
        uint256 initialContractBalance = _getBalance(address(escrow), true);
        uint256 initialPayerBalance = _getBalance(payer1, true);

        bytes32 paymentId = _refundTest(amount, refundAmount, payer1, receiver1, receiver1);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, amount / 5);

        Payment memory payment = _getPayment(paymentId);
        assertEq(payment.amountRefunded, refundAmount * 2);
        assertEq(payment.amount, amount);

        uint256 finalContractBalance = _getBalance(address(escrow), true);
        uint256 finalPayerBalance = _getBalance(payer1, true);

        assertEq(finalContractBalance, initialContractBalance + (amount - refundAmount * 2));
        assertEq(finalPayerBalance, initialPayerBalance - (amount - refundAmount * 2));
    }

    function testNotPossibleToRefundIfNotPartyOrArbiter() public {
        uint256 amount = 100_000_000;
        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(payer1);
        vm.expectRevert();
        escrow.refundPayment(paymentId, amount);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, amount);
    }

    function testCannotRefundMoreThanAmount() public {
        uint256 amount = 100_000_000;
        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(arbiter);
        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, amount + 1);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, amount);
    }

    function testCannotRefundMoreThanAmountWithMultipleRefunds() public {
        uint256 amount = 100_000_000;
        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, amount - 2);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, 1);

        // now total refunded = amount - 1
        vm.prank(arbiter);
        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, 100);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, 1);
        // total refunded now = amount
    }

    function testFailRefundAfterReleaseWithActiveEscrow() public {
        // Exploit: malcious actor is able to refund the payment after it has been released stealing the funds in escrow 
        // 1. Place a payment from payer1 to receiver1
        // 2. malicious actor pays self through escrow and releases the payment to self
        // 3. malicious actor refunds the payment to self, since no check for released payment, the funds are refunded to the malicious actor
        // 4. escrow balance is drained to 0
        uint256 amountEscrowed = 1 ether;
        uint256 amountReleased = 1 ether;

        // Record initial balances
        uint256[] memory initialBalances = _recordBalances();
        console.log("Initial Balances: ");
        for (uint256 i = 0; i < initialBalances.length; i++) {
            console.log(initialBalances[i]);
        }

        // First payment: From payer1 to receiver1, stays in escrow
        bytes32 paymentIdEscrowed = keccak256("payment-escrowed");
        _placePayment(paymentIdEscrowed, payer1, receiver1, amountEscrowed, false);
        console.log("Escrow Balance After First Payment: ", address(escrow).balance);

        // Second payment: From payer2 to receiver2, will be fully released
        bytes32 paymentIdReleased = keccak256("payment-released");
        _placePayment(paymentIdReleased, payer2, receiver2, amountReleased, false);

        uint256 escrowBalanceAfterSecond = address(escrow).balance;
        console.log("Escrow Balance After Second Payment: ", escrowBalanceAfterSecond);

        // Release the second payment completely
        vm.prank(payer2);
        escrow.releaseEscrow(paymentIdReleased);
        vm.prank(receiver2);
        escrow.releaseEscrow(paymentIdReleased);

        // After releasing the second payment
        uint256 escrowBalanceAfterRelease = address(escrow).balance;
        console.log("Escrow Balance After Release: ", escrowBalanceAfterRelease);

        // Ensure the second payment is fully released
        Payment memory releasedPayment = _getPayment(paymentIdReleased);
        assertTrue(releasedPayment.released);

        // Malicious refund attempt by receiver2
        vm.prank(receiver2);
        escrow.refundPayment(paymentIdReleased, amountReleased);

        // Final balances after the malicious refund
        uint256[] memory finalBalances = _recordBalances();
        console.log("Final Balances: ");
        for (uint256 i = 0; i < finalBalances.length; i++) {
            console.log(finalBalances[i]);
        }
        // finalBalances[0] - Escrow contract balance
        // finalBalances[1] - Receiver1's balance
        // finalBalances[2] - Payer1's balance
        // finalBalances[3] - Receiver2's balance
        // finalBalances[4] - Payer2's balance

        // Assertions
        // Check if Receiver2 profited (exploit success)
        assertTrue(
            finalBalances[3] + finalBalances[4] > initialBalances[3] + initialBalances[4],
            "Exploit success: Receiver2 profited"
        );

        // Check if Payer1 and Receiver1 lost funds, along with escrow depletion
        assertTrue(
            finalBalances[1] + finalBalances[2] + finalBalances[0] < initialBalances[1] + initialBalances[2] + initialBalances[0],
            "Exploit success: Payer1 and Receiver1 lost funds"
        );

        // Ensure the escrow balance was drained to 0
        assertEq(finalBalances[0], 0, "Exploit success: Escrow balance drained");
    }

    function testCannotRefundAfterRelease() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("refund-after-release-test");

        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Approvals to release escrow
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        // Verify payment is released
        Payment memory payment = _getPayment(paymentId);
        assertTrue(payment.released);

        // Attempt to refund after release
        vm.prank(receiver1);
        vm.expectRevert("Payment already released");
        escrow.refundPayment(paymentId, amount / 2);
    }


    function testZeroAmountRefundNoStateChange() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("zero-amount-refund-test");

        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Record initial state and balances
        Payment memory paymentBefore = _getPayment(paymentId);
        uint256 escrowBalanceBefore = address(escrow).balance;

        // Attempt a zero-amount refund
        vm.prank(receiver1);
        escrow.refundPayment(paymentId, 0);

        // Verify state remains unchanged
        Payment memory paymentAfter = _getPayment(paymentId);
        assertEq(paymentAfter.amountRefunded, paymentBefore.amountRefunded);
        assertEq(paymentAfter.released, paymentBefore.released);

        // Verify no balance changes
        uint256 escrowBalanceAfter = address(escrow).balance;
        assertEq(escrowBalanceAfter, escrowBalanceBefore);
    }

    function testCannotRefundAlreadyFullyRefundedPayment() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("already-fully-refunded");

        // Place the payment
        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Fully refund the payment
        vm.prank(receiver1);
        escrow.refundPayment(paymentId, amount);

        // Attempt to refund again
        vm.prank(receiver1);
        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, 1);
    }

    function testCannotRefundByPayer() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("refund-by-payer");

        // Place the payment
        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Attempt refund by payer (not authorized)
        vm.prank(payer1);
        vm.expectRevert("Unauthorized");
        escrow.refundPayment(paymentId, amount);
    }

    function testStateUnchangedAfterFailedRefund() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("state-unchanged-failed-refund");

        // Place the payment
        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Record initial state
        Payment memory paymentBefore = _getPayment(paymentId);

        // Attempt an invalid refund
        vm.prank(receiver1);
        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, amount + 1);

        // Verify state remains unchanged
        Payment memory paymentAfter = _getPayment(paymentId);
        _verifyPayment(paymentAfter, paymentBefore);
    }

    function testRefundExceedsRemainingAmount() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("refund-exceeds");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Refund part of the amount first
        uint256 partialRefund = amount / 2;
        vm.prank(receiver1);
        escrow.refundPayment(paymentId, partialRefund);

        // Attempt to refund more than the remaining amount
        vm.prank(receiver1);
        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, partialRefund + 1);
    }

    function testZeroAmountRefund() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("zero-amount-refund");
        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Attempt a zero-amount refund
        vm.prank(receiver1);
        escrow.refundPayment(paymentId, 0);

        // Verify that no state changes occurred
        Payment memory payment = _getPayment(paymentId);
        assertEq(payment.amountRefunded, 0); 
        assertFalse(payment.released);      
    }

    // Fee Amounts
    function testFeesAreCalculatedCorrectly() public {
        uint256 feeBps = 200; // 2%
        vm.prank(dao);
        systemSettings.setFeeBps(feeBps);

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10_000_000;
        uint256 receiverInitialAmount = _getBalance(receiver1, true);

        assertEq(_getBalance(vaultAddress, true), 0);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        uint256 feeAmount = (amount * feeBps) / 10_000;
        assertEq(_getBalance(vaultAddress, true), feeAmount);
        assertEq(_getBalance(receiver1, true), receiverInitialAmount + (amount - feeAmount));
    }

    function testFeeCanBeZeroPercent() public {
        vm.prank(dao);
        systemSettings.setFeeBps(0);

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10_000_000;
        uint256 receiverInitialAmount = _getBalance(receiver1, true);

        assertEq(_getBalance(vaultAddress, true), 0);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        assertEq(_getBalance(vaultAddress, true), 0);
        assertEq(_getBalance(receiver1, true), receiverInitialAmount + amount);
    }

    function testFeeCanBe100Percent() public {
        vm.prank(dao);
        systemSettings.setFeeBps(10_000);

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10_000_000;
        uint256 receiverInitialAmount = _getBalance(receiver1, true);

        assertEq(_getBalance(vaultAddress, true), 0);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        assertEq(_getBalance(vaultAddress, true), amount);
        assertEq(_getBalance(receiver1, true), receiverInitialAmount);
    }

    function testFeeCalculatedFromRemainingAfterRefund() public {
        uint256 feeBps = 200; //2%
        vm.prank(dao);
        systemSettings.setFeeBps(feeBps);

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10_000_000;
        uint256 refundAmount = 40_000;
        uint256 receiverInitialAmount = _getBalance(receiver1, true);

        assertEq(_getBalance(vaultAddress, true), 0);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, refundAmount);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        uint256 feeAmount = (amount - refundAmount) * feeBps / 10_000;
        assertEq(_getBalance(vaultAddress, true), feeAmount);
        assertEq(_getBalance(receiver1, true), receiverInitialAmount + (amount - refundAmount - feeAmount));
    }

    function testNoFeeForFullyRefundedPayment() public {
        uint256 feeBps = 200; 
        vm.prank(dao);
        systemSettings.setFeeBps(feeBps);

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10_000_000;
        uint256 refundAmount = amount;
        uint256 receiverInitialAmount = _getBalance(receiver1, true);

        assertEq(_getBalance(vaultAddress, true), 0);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(arbiter);
        escrow.refundPayment(paymentId, refundAmount);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        assertEq(_getBalance(vaultAddress, true), 0);
        assertEq(_getBalance(receiver1, true), receiverInitialAmount);
    }

    function testNoFeeIfFeeRateGreaterThan100Percent() public {
        vm.prank(dao);
        systemSettings.setFeeBps(20101); // >100%

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10_000_000;
        uint256 receiverInitialAmount = _getBalance(receiver1, true);

        assertEq(_getBalance(vaultAddress, true), 0);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        // fee is ignored if fee > 100%
        assertEq(_getBalance(vaultAddress, true), 0);
        assertEq(_getBalance(receiver1, true), receiverInitialAmount + amount);
    }

    // Edge Cases
    function testPayerAndReceiverAreSame() public {
        uint256 initialPayerBalance = _getBalance(payer1, true);
        uint256 amount = 10_000_000;

        bytes32 paymentId = keccak256("0x01");
        _placePayment(paymentId, payer1, payer1, amount, true);

        uint256 newPayerBalance = _getBalance(payer1, true);
        assertEq(newPayerBalance, initialPayerBalance - amount);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        Payment memory payment = _getPayment(paymentId);
        _verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: payer1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: true,
            receiverReleased: true,
            released: true,
            currency: address(testToken)
        }));

        uint256 finalPayerBalance = _getBalance(payer1, true);
        assertEq(finalPayerBalance, initialPayerBalance);
    }

    function testGetPaymentForNonExistentID() public {
        bytes32 nonExistentPaymentId = keccak256("non-existent-payment");

        Payment memory payment = escrow.getPayment(nonExistentPaymentId);

        // Expect all fields to be zeroed out for non-existent payments
        assertEq(payment.id, bytes32(0));
        assertEq(payment.payer, address(0));
        assertEq(payment.receiver, address(0));
        assertEq(payment.amount, 0);
        assertEq(payment.amountRefunded, 0);
        assertEq(payment.currency, address(0));
        assertFalse(payment.payerReleased);
        assertFalse(payment.receiverReleased);
        assertFalse(payment.released);
    }





    function testContractCanReceiveEthDirectly() public {
        uint256 initialBalance = address(escrow).balance;
        uint256 transferAmount = 1 ether;

        vm.prank(payer1);
        (bool success,) = address(escrow).call{value: transferAmount}("");
        assertTrue(success);

        assertEq(address(escrow).balance, initialBalance + transferAmount);
    }

    function testPaymentWithSelfAsPayerAndReceiver() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("self-as-payer-and-receiver-test");
        uint256 initialPayerBalance = _getBalance(payer1, false);

        // Place a payment where payer and receiver are the same
        _placePayment(paymentId, payer1, payer1, amount, false);

        // Verify payment details
        Payment memory payment = _getPayment(paymentId);
        assertEq(payment.payer, payer1);
        assertEq(payment.receiver, payer1);
        assertEq(payment.amount, amount);

        // Approve release as payer
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        // Approve release as receiver (same address)
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        // Verify payment is fully released
        Payment memory releasedPayment = _getPayment(paymentId);
        assertTrue(releasedPayment.payerReleased);
        assertTrue(releasedPayment.receiverReleased);
        assertTrue(releasedPayment.released);

        // Verify no net balance change for the user
        uint256 finalPayerBalance = _getBalance(payer1, false);
       
        assertEq(finalPayerBalance, initialPayerBalance);
    }


    // Invalid Payment tests

    function testCannotPlacePaymentWithZeroAmount() public {
        bytes32 paymentId = keccak256("zero-amount-payment");

        // Attempt to place a payment with zero amount (native currency)
        vm.prank(payer1);
        vm.expectRevert("InvalidAmount");
        escrow.placePayment{value: 0}(
            PaymentInput({
                currency: address(0),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: 0
            })
        );

        // Attempt to place a payment with zero amount (token)
        vm.prank(payer1);
        testToken.approve(address(escrow), 0);
        vm.expectRevert("InvalidAmount");
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: 0
            })
        );
    }

    function testCannotPlacePaymentToZeroAddress() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("payment-to-zero-address");

        // Attempt to place a payment with zero address as the receiver
        vm.prank(payer1);
        vm.expectRevert("InvalidReceiver");
        escrow.placePayment{value: amount}(
            PaymentInput({
                currency: address(0),
                id: paymentId,
                receiver: address(0),
                payer: payer1,
                amount: amount
            })
        );
    }

    function testPlacePaymentInsufficientETH() public {
        uint256 amount = 1 ether; 
        bytes32 paymentId = keccak256("insufficient-eth");

        vm.prank(payer1);
        vm.expectRevert("InsufficientAmount");
        escrow.placePayment{value: amount - 1}(
            PaymentInput({
                currency: address(0),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
    }

    function testCannotPlacePaymentWithFailedTokenTransfer() public {
        // Deploy a token contract that fails transfers
        FailingToken failingToken = new FailingToken();

        // Mint tokens to payer1
        failingToken.transfer(payer1, 1_000_000);

        // Attempt to place a payment with the failing token
        bytes32 paymentId = keccak256("failed-token-payment");
        uint256 amount = 100_000;

        // Approve the escrow contract to spend tokens
        vm.startPrank(payer1);
        failingToken.approve(address(escrow), amount);

        failingToken.setFailTransfers(true);

        // Expect the 'TokenPaymentFailed' revert
        vm.expectRevert("TokenPaymentFailed");
        escrow.placePayment(
            PaymentInput({
                currency: address(failingToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
        vm.stopPrank();
    }

    function testPaymentTransferFailedRevertOnFailedNativeTransfer() public {
        // Create a contract that reverts on receiving ETH
        RevertingReceiver revReceiver = new RevertingReceiver();
        bytes32 paymentId = keccak256("payment-transfer-failed-native");
        uint256 amount = 1 ether;

        _placePayment(paymentId, payer1, address(revReceiver), amount, false);

        // payer releases first
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        // expect a transfer fail revert when receiver tries to release and send funds
        vm.expectRevert("PaymentTransferFailed");

        vm.prank(address(revReceiver));
        escrow.releaseEscrow(paymentId);
    }

    function testPaymentTransferFailedRevertOnFailedTokenTransfer() public {
        FailingToken failingToken = new FailingToken();
        bytes32 paymentId = keccak256("payment-transfer-failed-token");
        uint256 amount = 1000;

        // Give payer1 some tokens so the placePayment call can succeed
        failingToken.transfer(payer1, 2000);

        // Ensure normal operations during placePayment
        vm.prank(payer1);
        failingToken.approve(address(escrow), amount);
        vm.prank(payer1);
        escrow.placePayment(
            PaymentInput({
                currency: address(failingToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );

        // First approval succeeds; token transfers normally at this stage
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        // set the token to fail on transfer
        failingToken.setFailTransfers(true);

        // expect a transfer fail revert when receiver tries to release and send funds
        vm.expectRevert("PaymentTransferFailed");

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
    }

    // Event Tests

    // events 
    // TODO: add events to interface and remove these
    event PaymentReceived(
        bytes32 indexed paymentId,
        address indexed to,
        address from,
        address currency,
        uint256 amount
    );

    event ReleaseAssentGiven (
        bytes32 indexed paymentId,
        address assentingAddress,
        //TODO: make enum
        uint8 assentType // 1 = payer, 2 = receiver, 3 = arbiter
    );

    event EscrowReleased (
        bytes32 indexed paymentId,
        uint256 amount,
        uint256 fee
    );

    event PaymentTransferred (
        bytes32 indexed paymentId, 
        address currency, 
        uint256 amount 
    );

    event PaymentTransferFailed (
        bytes32 indexed paymentId, 
        address currency, 
        uint256 amount 
    );

    function testPaymentReceivedEventEmittedForNativePayment() public {
        uint256 amount = 1 ether;
        bytes32 paymentId = keccak256("payment-received-test-native");

        vm.expectEmit(true, true, true, true);
        emit PaymentReceived(paymentId, receiver1, payer1, address(0), amount);

        vm.prank(payer1);
        escrow.placePayment{value: amount}(
            PaymentInput({
                currency: address(0),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
    }

    function testPaymentReceivedEventEmittedForTokenPayment() public {
        uint256 amount = 1000;
        bytes32 paymentId = keccak256("payment-received-test-token");

        vm.prank(payer1);
        testToken.approve(address(escrow), amount);

        vm.expectEmit(true, true, true, true);
        emit PaymentReceived(paymentId, receiver1, payer1, address(testToken), amount);

        vm.prank(payer1);
        escrow.placePayment(
            PaymentInput({
                currency: address(testToken),
                id: paymentId,
                receiver: receiver1,
                payer: payer1,
                amount: amount
            })
        );
    }
    
    function testReleaseAssentGivenEventEmittedByReceiver() public {
        bytes32 paymentId = keccak256("release-assent-receiver");
        uint256 amount = 5000;
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.expectEmit(true, true, true, true);
        // receiver assentType = 1
        emit ReleaseAssentGiven(paymentId, receiver1, 1);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
    }

    function testReleaseAssentGivenEventEmittedByPayer() public {
        bytes32 paymentId = keccak256("release-assent-payer");
        uint256 amount = 5000;
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.expectEmit(true, true, true, true);
        // payer assentType = 2
        emit ReleaseAssentGiven(paymentId, payer1, 2);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
    }

    function testReleaseAssentGivenEventEmittedByArbiter() public {
        bytes32 paymentId = keccak256("release-assent-arbiter");
        uint256 amount = 5000;
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.expectEmit(true, true, true, true);
        // arbiter assentType = 3
        emit ReleaseAssentGiven(paymentId, arbiter, 3);

        vm.prank(arbiter);
        escrow.releaseEscrow(paymentId);
    }

    function testEscrowReleasedEventEmittedOnlyAfterBothApprovalsNative() public {
        bytes32 paymentId = keccak256("escrow-released-native");
        uint256 amount = 1 ether;
        _placePayment(paymentId, payer1, receiver1, amount, false);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);

        // Calculate fee
        uint256 feeBps = systemSettings.feeBps();
        uint256 fee = (amount * feeBps) / 10000;
        if (fee > amount) fee = 0;
        uint256 amountToPay = amount - fee;

        // Ensure event is emitted after the second approval
        vm.expectEmit(true, true, true, true);
        emit EscrowReleased(paymentId, amountToPay, fee);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);
    }

    function testEscrowReleasedEventEmittedOnlyAfterBothApprovalsToken() public {
        bytes32 paymentId = keccak256("escrow-released-token");
        uint256 amount = 10_000;
        _placePayment(paymentId, payer1, receiver1, amount, true);

        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        // Calculate fee
        uint256 feeBps = systemSettings.feeBps();
        uint256 fee = (amount * feeBps) / 10000;
        if (fee > amount) fee = 0;
        uint256 amountToPay = amount - fee;

        // Expect the EscrowReleased event only after the second approval
        vm.expectEmit(true, true, true, true);
        emit EscrowReleased(paymentId, amountToPay, fee);

        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
    }

    function testPaymentTransferredEventEmittedOnSuccessfulTransferDuringRelease() public {
        // With zero fees and both approvals payment transfers successfully
        vm.prank(dao);
        systemSettings.setFeeBps(0);

        bytes32 paymentId = keccak256("payment-transferred-success-release");
        uint256 amount = 1_000;
        _placePayment(paymentId, payer1, receiver1, amount, true);

        // Receiver approves
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        vm.expectEmit(true, true, true, true);
        // The receiver should get full amount in a successful transfer
        emit PaymentTransferred(paymentId, address(testToken), amount);

        // Payer approves triggering release and transfer
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
    }

    function testPaymentTransferredEventEmittedOnSuccessfulRefund() public {
        bytes32 paymentId = keccak256("payment-transferred-success-refund");
        uint256 amount = 10_000;
        _placePayment(paymentId, payer1, receiver1, amount, true);

        // reciever issues refund
        uint256 refundAmount = 1_000;

        vm.expectEmit(true, true, true, true);
        emit PaymentTransferred(paymentId, address(testToken), refundAmount);

        vm.prank(receiver1);
        escrow.refundPayment(paymentId, refundAmount);
    }
}

// This contract reverts on receiving eth enabling a scenario to test PaymentTransferFailed
contract RevertingReceiver {
    receive() external payable {
        revert("I don't accept ETH");
    }
    // test function so foundry ignores this contract
    function test() public pure {}
}