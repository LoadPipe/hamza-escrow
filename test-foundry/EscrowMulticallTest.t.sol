// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/SecurityContext.sol";
import "../src/TestToken.sol";
import "../src/SystemSettings.sol";
import "../src/PaymentEscrow.sol";
import "../src/EscrowMulticall.sol";
import { EscrowMulticall } from "../src/EscrowMulticall.sol";

import { Payment } from "../src/PaymentInput.sol";
import {MulticallPaymentInput} from "../src/EscrowMulticall.sol";
import {FailingToken} from "../src/FailingToken.sol";

contract EscrowMulticallTest is Test {
    SecurityContext securityContext;
    PaymentEscrow escrow;
    PaymentEscrow escrow1;
    PaymentEscrow escrow2;
    PaymentEscrow escrow3;
    TestToken testToken;
    SystemSettings systemSettings;
    EscrowMulticall multicall;

    address admin;
    address nonOwner;
    address vaultAddress;
    address payer1;
    address payer2;
    address payer3;
    address receiver1;
    address receiver2;
    address receiver3;
    address arbiter;
    address dao;

    bytes32 constant ARBITER_ROLE = 0xbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae;
    bytes32 constant DAO_ROLE = 0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603;

    function setUp() public {
        admin = address(0x10);
        nonOwner = address(0x11);
        vaultAddress = address(0x12);
        payer1 = address(0x13);
        payer2 = address(0x14);
        payer3 = address(0x15);
        receiver1 = address(0x16);
        receiver2 = address(0x17);
        receiver3 = address(0x18);
        arbiter = address(0x19);
        dao = address(0x20);

        vm.deal(payer1, 1 ether);
        vm.deal(payer2, 1 ether);
        vm.deal(payer3, 1 ether);

        vm.startPrank(admin);
        securityContext = new SecurityContext(admin);
        testToken = new TestToken("XYZ", "ZYX");
        systemSettings = new SystemSettings(ISecurityContext(address(securityContext)), vaultAddress, 0);

        escrow = new PaymentEscrow(ISecurityContext(address(securityContext)), ISystemSettings(address(systemSettings)));
        escrow1 = escrow;
        escrow2 = new PaymentEscrow(ISecurityContext(address(securityContext)), ISystemSettings(address(systemSettings)));
        escrow3 = new PaymentEscrow(ISecurityContext(address(securityContext)), ISystemSettings(address(systemSettings)));

        multicall = new EscrowMulticall();

        securityContext.grantRole(ARBITER_ROLE, vaultAddress);
        securityContext.grantRole(ARBITER_ROLE, arbiter);
        securityContext.grantRole(DAO_ROLE, dao);

        testToken.mint(nonOwner, 10000000000);
        testToken.mint(payer1, 10000000000);
        testToken.mint(payer2, 10000000000);
        testToken.mint(payer3, 10000000000);
        vm.stopPrank();
    }

    function getBalance(address addr, bool isToken) internal view returns (uint256) {
        return isToken ? testToken.balanceOf(addr) : addr.balance;
    }


    function convertPayment(Payment memory p) internal pure returns (Payment memory) {
        return Payment({
            id: p.id,
            payer: p.payer,
            receiver: p.receiver,
            amount: p.amount,
            amountRefunded: p.amountRefunded,
            payerReleased: p.payerReleased,
            receiverReleased: p.receiverReleased,
            released: p.released,
            currency: p.currency
        });
    }

    function placePayment(
        bytes32 paymentId,
        address payerAccount,
        address receiverAccount,
        uint256 amount,
        bool isToken
    ) internal returns (Payment memory) {
        if (isToken) {
            vm.startPrank(payerAccount);
            testToken.approve(address(multicall), amount);
            vm.stopPrank();
        }

        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: isToken ? address(testToken) : address(0),
            id: paymentId,
            receiver: receiverAccount,
            payer: payerAccount,
            amount: amount
        });

        vm.startPrank(payerAccount);
        if (isToken) {
            multicall.multipay(arr);
        } else {
            multicall.multipay{value: amount}(arr);
        }
        vm.stopPrank();

        Payment memory pm = escrow.getPayment(paymentId);
        return convertPayment(pm);
    }

    function verifyPayment(Payment memory actual, Payment memory expected) internal {
        assertEq(actual.id, expected.id);
        assertEq(actual.payer, expected.payer);
        assertEq(actual.receiver, expected.receiver);
        assertEq(actual.amount, expected.amount);
        assertEq(actual.amountRefunded, expected.amountRefunded);
        assertEq(actual.currency, expected.currency);
        assertEq(actual.receiverReleased, expected.receiverReleased);
        assertEq(actual.payerReleased, expected.payerReleased);
        assertEq(actual.released, expected.released);
    }

    // Deployment
    function testDeploymentArbiterRole() public {
        bool hasArbiter = securityContext.hasRole(ARBITER_ROLE, arbiter);
        bool hasNonOwnerArbiter = securityContext.hasRole(ARBITER_ROLE, nonOwner);
        bool hasVaultArbiter = securityContext.hasRole(ARBITER_ROLE, vaultAddress);

        assertTrue(hasArbiter);
        assertFalse(hasNonOwnerArbiter);
        assertTrue(hasVaultArbiter);
    }

    // Place Payments
    function testCanPlaceSingleNativePayment() public {
        uint256 initialContractBalance = getBalance(address(escrow), false);
        uint256 initialPayerBalance = getBalance(payer1, false);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        Payment memory payment = placePayment(paymentId, payer1, receiver1, amount, false);
        verifyPayment(payment, Payment({
            id: paymentId,
            payer: payer1,
            receiver: receiver1,
            amount: amount,
            amountRefunded: 0,
            payerReleased: false,
            receiverReleased: false,
            released: false,
            currency: address(0)
        }));

        uint256 newContractBalance = getBalance(address(escrow), false);
        uint256 newPayerBalance = getBalance(payer1, false);

        assertTrue(newPayerBalance <= initialPayerBalance - amount);
        assertEq(newContractBalance, initialContractBalance + amount);
    }

    function testCanPlaceSingleTokenPayment() public {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 initialPayerBalance = getBalance(payer1, true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        Payment memory payment = placePayment(paymentId, payer1, receiver1, amount, true);
        verifyPayment(payment, Payment({
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

        uint256 newContractBalance = getBalance(address(escrow), true);
        uint256 newPayerBalance = getBalance(payer1, true);

        assertTrue(newPayerBalance <= initialPayerBalance - amount);
        assertEq(newContractBalance, initialContractBalance + amount);
    }

    function testCannotPlaceDuplicatePaymentId() public {
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");
        placePayment(paymentId, payer1, receiver1, amount, false);

        vm.startPrank(payer1);
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(0),
            id: paymentId,
            receiver: receiver1,
            payer: payer1,
            amount: amount
        });
        vm.expectRevert("PaymentFailure");
        multicall.multipay{value: amount}(arr);
        vm.stopPrank();
    }

    function testCannotPlaceOrderWithoutCorrectNativeAmount() public {
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        vm.startPrank(payer1);
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(0),
            id: paymentId,
            receiver: receiver1,
            payer: payer1,
            amount: amount
        });
        vm.expectRevert("InsufficientAmount");
        multicall.multipay{value: amount - 1}(arr);
        vm.stopPrank();
    }

    function testCannotPlaceOrderWithoutCorrectTokenApproval() public {
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        vm.startPrank(payer1);
        testToken.approve(address(escrow), amount - 1);
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(testToken),
            id: paymentId,
            receiver: receiver1,
            payer: payer1,
            amount: amount
        });
        vm.expectRevert();
        multicall.multipay(arr);
        vm.stopPrank();
    }

    function testCannotPlaceOrderWithoutCorrectTokenBalance() public {
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");
        vm.startPrank(payer1);
        // transfer all payer1 tokens away
        testToken.transfer(payer2, testToken.balanceOf(payer1));
        testToken.approve(address(escrow), amount);
        vm.expectRevert();
        escrow.placePayment(PaymentInput({
            currency: address(testToken),
            id: paymentId,
            receiver: receiver1,
            payer: payer1,
            amount: amount
        }));
        vm.stopPrank();
    }

    // Release Payments
    function testCannotReleasePaymentWithNoApprovals() public {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, true);
        uint256 newContractBalance = getBalance(address(escrow), true);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.startPrank(arbiter);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), true);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCannotReleasePaymentWithOnlyPayerApproval() public {
        uint256 initialContractBalance = getBalance(address(escrow), false);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, false);
        uint256 newContractBalance = getBalance(address(escrow), false);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), false);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCannotReleasePaymentWithOnlyReceiverApproval() public {
        uint256 initialContractBalance = getBalance(address(escrow), false);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, false);
        uint256 newContractBalance = getBalance(address(escrow), false);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), false);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCanReleaseNativePaymentWithBothApprovals() public {
        uint256 initialContractBalance = getBalance(address(escrow), false);
        uint256 initialReceiverBalance = getBalance(receiver1, false);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, false);
        uint256 newContractBalance = getBalance(address(escrow), false);
        uint256 newReceiverBalance = getBalance(receiver1, false);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), false);
        uint256 finalReceiverBalance = getBalance(receiver1, false);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertTrue(finalReceiverBalance >= initialReceiverBalance);
    }

    function testCanReleaseTokenPaymentWithBothApprovals() public {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 initialReceiverBalance = getBalance(receiver1, true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, true);
        uint256 newContractBalance = getBalance(address(escrow), true);
        uint256 newReceiverBalance = getBalance(receiver1, true);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), true);
        uint256 finalReceiverBalance = getBalance(receiver1, true);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertEq(finalReceiverBalance, newReceiverBalance + amount);
    }

    function testArbiterCanReleasePaymentOnBehalfOfPayer() public {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 initialReceiverBalance = getBalance(receiver1, true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        vm.startPrank(payer1);
        testToken.approve(address(escrow), amount);
        vm.stopPrank();
        placePayment(paymentId, payer1, receiver1, amount, true);

        uint256 newContractBalance = getBalance(address(escrow), true);
        uint256 newReceiverBalance = getBalance(receiver1, true);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(arbiter);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), true);
        uint256 finalReceiverBalance = getBalance(receiver1, true);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertEq(finalReceiverBalance, newReceiverBalance + amount);
    }

    function testCannotReleasePaymentIfNotPartyToIt() public {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, true);
        uint256 newContractBalance = getBalance(address(escrow), true);
        assertEq(newContractBalance, initialContractBalance + amount);

        vm.startPrank(nonOwner);
        vm.expectRevert("Unauthorized");
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalContractBalance = getBalance(address(escrow), true);
        assertEq(finalContractBalance, newContractBalance);
    }

    function testCannotReleasePaymentTwice() public {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 initialReceiverBalance = getBalance(receiver1, true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, receiver1, amount, true);
        uint256 newContractBalance = getBalance(address(escrow), true);
        uint256 newReceiverBalance = getBalance(receiver1, true);
        assertEq(newContractBalance, initialContractBalance + amount);
        assertEq(newReceiverBalance, initialReceiverBalance);

        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        uint256 finalContractBalance = getBalance(address(escrow), true);
        uint256 finalReceiverBalance = getBalance(receiver1, true);
        assertEq(finalContractBalance, newContractBalance - amount);
        assertEq(finalReceiverBalance, newReceiverBalance + amount);
    }

    // Refund Payments
    function refundTest(
        uint256 amount,
        uint256 refundAmount,
        address payerAccount,
        address receiverAccount,
        address refunderAccount
    ) internal returns (bytes32) {
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 initialPayerBalance = getBalance(payerAccount, true);
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payerAccount, receiverAccount, amount, true);

        vm.startPrank(refunderAccount);
        escrow.refundPayment(paymentId, refundAmount);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        assertEq(payment.amountRefunded, refundAmount);
        assertEq(payment.amount, amount);

        uint256 finalContractBalance = getBalance(address(escrow), true);
        uint256 finalPayerBalance = getBalance(payerAccount, true);

        assertEq(finalContractBalance, initialContractBalance + (amount - refundAmount));
        assertEq(finalPayerBalance, initialPayerBalance - (amount - refundAmount));

        return paymentId;
    }

    function testArbiterCanCausePartialRefund() public {
        uint256 amount = 1000000;
        refundTest(amount, amount / 5, payer1, receiver1, arbiter);
    }

    function testReceiverCanCausePartialRefund() public {
        uint256 amount = 1000000;
        refundTest(amount, amount / 5, payer1, receiver1, receiver1);
    }

    function testArbiterCanCauseFullRefund() public {
        uint256 amount = 1000000;
        refundTest(amount, amount, payer1, receiver1, arbiter);
    }

    function testReceiverCanCauseFullRefund() public {
        uint256 amount = 1000000;
        refundTest(amount, amount, payer1, receiver1, receiver1);
    }

    function testMultiplePartialRefunds() public {
        uint256 amount = 1000000;
        uint256 refundAmount = amount / 5;
        uint256 initialContractBalance = getBalance(address(escrow), true);
        uint256 initialPayerBalance = getBalance(payer1, true);

        bytes32 paymentId = refundTest(amount, refundAmount, payer1, receiver1, receiver1);

        vm.startPrank(arbiter);
        escrow.refundPayment(paymentId, amount / 5);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        assertEq(payment.amountRefunded, refundAmount * 2);
        assertEq(payment.amount, amount);

        uint256 finalContractBalance = getBalance(address(escrow), true);
        uint256 finalPayerBalance = getBalance(payer1, true);

        assertEq(finalContractBalance, initialContractBalance + (amount - refundAmount * 2));
        assertEq(finalPayerBalance, initialPayerBalance - (amount - refundAmount * 2));
    }

    function testNotPossibleToRefundIfNotParty() public {
        uint256 amount = 100000000;
        bytes32 paymentId = keccak256("0x01");
        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(payer1);
        vm.expectRevert();
        escrow.refundPayment(paymentId, amount);
        vm.stopPrank();

        vm.startPrank(arbiter);
        escrow.refundPayment(paymentId, amount);
        vm.stopPrank();
    }

    function testNotPossibleToRefundMoreThanAmount() public {
        uint256 amount = 100000000;
        bytes32 paymentId = keccak256("0x01");
        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(arbiter);
        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, amount + 1);

        escrow.refundPayment(paymentId, amount);
        vm.stopPrank();
    }

    function testNotPossibleToRefundMoreThanAmountWithMultipleRefunds() public {
        uint256 amount = 100000000;
        bytes32 paymentId = keccak256("0x01");
        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(arbiter);
        escrow.refundPayment(paymentId, amount - 2);
        escrow.refundPayment(paymentId, 1);

        vm.expectRevert("AmountExceeded");
        escrow.refundPayment(paymentId, 100);

        escrow.refundPayment(paymentId, 1);
        vm.stopPrank();
    }

    // Fee Amounts
    function testFeesAreCalculatedCorrectly() public {
        uint256 feeBps = 200;
        vm.startPrank(dao);
        systemSettings.setFeeBps(feeBps);
        vm.stopPrank();

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10000000;
        uint256 receiverInitialAmount = getBalance(receiver1, true);
        assertEq(getBalance(vaultAddress, true), 0);

        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        uint256 feeAmount = (amount * feeBps) / 10000;
        assertEq(getBalance(vaultAddress, true), feeAmount);
        assertEq(getBalance(receiver1, true), receiverInitialAmount + (amount - feeAmount));
    }

    function testFeeCanBeZeroPercent() public {
        vm.startPrank(dao);
        systemSettings.setFeeBps(0);
        vm.stopPrank();

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10000000;
        uint256 receiverInitialAmount = getBalance(receiver1, true);
        assertEq(getBalance(vaultAddress, true), 0);

        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        assertEq(getBalance(vaultAddress, true), 0);
        assertEq(getBalance(receiver1, true), receiverInitialAmount + amount);
    }

    function testFeeCanBe100Percent() public {
        vm.startPrank(dao);
        systemSettings.setFeeBps(10000);
        vm.stopPrank();

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10000000;
        uint256 receiverInitialAmount = getBalance(receiver1, true);
        assertEq(getBalance(vaultAddress, true), 0);

        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        assertEq(getBalance(vaultAddress, true), amount);
        assertEq(getBalance(receiver1, true), receiverInitialAmount);
    }

    function testFeeCalculatedAfterRefund() public {
        uint256 feeBps = 200;
        vm.startPrank(dao);
        systemSettings.setFeeBps(feeBps);
        vm.stopPrank();

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10000000;
        uint256 refundAmount = 40000;
        uint256 receiverInitialAmount = getBalance(receiver1, true);

        assertEq(getBalance(vaultAddress, true), 0);
        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(arbiter);
        escrow.refundPayment(paymentId, refundAmount);
        vm.stopPrank();

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        uint256 feeAmount = ((amount - refundAmount) * feeBps) / 10000;
        assertEq(getBalance(vaultAddress, true), feeAmount);
        assertEq(getBalance(receiver1, true), receiverInitialAmount + (amount - refundAmount - feeAmount));
    }

    function testNoFeeIfFullyRefunded() public {
        uint256 feeBps = 200;
        vm.startPrank(dao);
        systemSettings.setFeeBps(feeBps);
        vm.stopPrank();

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10000000;
        uint256 refundAmount = amount;
        uint256 receiverInitialAmount = getBalance(receiver1, true);

        assertEq(getBalance(vaultAddress, true), 0);
        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(arbiter);
        escrow.refundPayment(paymentId, refundAmount);
        vm.stopPrank();

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        assertEq(getBalance(vaultAddress, true), 0);
        assertEq(getBalance(receiver1, true), receiverInitialAmount);
    }

    function testNoFeeIfFeeRateOver100Percent() public {
        vm.startPrank(dao);
        systemSettings.setFeeBps(20101);
        vm.stopPrank();

        bytes32 paymentId = keccak256("0x01");
        uint256 amount = 10000000;
        uint256 receiverInitialAmount = getBalance(receiver1, true);
        assertEq(getBalance(vaultAddress, true), 0);

        placePayment(paymentId, payer1, receiver1, amount, true);

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
        vm.startPrank(receiver1);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        assertEq(getBalance(vaultAddress, true), 0);
        assertEq(getBalance(receiver1, true), receiverInitialAmount + amount);
    }

    // Edge Cases
    function testPayerAndReceiverAreTheSame() public {
        uint256 initialPayerBalance = getBalance(payer1, true);
        uint256 amount = 10000000;
        bytes32 paymentId = keccak256("0x01");

        placePayment(paymentId, payer1, payer1, amount, true);
        uint256 newPayerBalance = getBalance(payer1, true);
        assertEq(newPayerBalance, initialPayerBalance - amount);

        vm.startPrank(payer1);
        escrow.releaseEscrow(paymentId);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        Payment memory payment = convertPayment(escrow.getPayment(paymentId));
        verifyPayment(payment, Payment({
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

        uint256 finalPayerBalance = getBalance(payer1, true);
        assertEq(finalPayerBalance, initialPayerBalance);
    }

    // Multicall
    function testMulticallDifferentEscrows() public {
        uint256 amount1 = 10000;
        uint256 amount2 = 22500;
        uint256 amount3 = 32500;
        bytes32 id1 = keccak256("0x01");
        bytes32 id2 = keccak256("0x02");
        bytes32 id3 = keccak256("0x03");

        vm.startPrank(payer1);
        testToken.approve(address(multicall), amount3);
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](3);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount1,
            id: id1
        });
        arr[1] = MulticallPaymentInput({
            contractAddress: address(escrow2),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount2,
            id: id2
        });
        arr[2] = MulticallPaymentInput({
            contractAddress: address(escrow3),
            currency: address(testToken),
            receiver: receiver1,
            payer: payer1,
            amount: amount3,
            id: id3
        });
        multicall.multipay{value: amount1 + amount2}(arr);
        vm.stopPrank();

        assertEq(getBalance(address(multicall), true), 0);
        assertEq(getBalance(address(multicall), false), 0);

        assertEq(getBalance(address(escrow1), true), 0);
        assertEq(getBalance(address(escrow1), false), amount1);
        assertEq(getBalance(address(escrow2), true), 0);
        assertEq(getBalance(address(escrow2), false), amount2);
        assertEq(getBalance(address(escrow3), true), amount3);
        assertEq(getBalance(address(escrow3), false), 0);
    }

    function testMulticallMultiplePaymentsSameEscrow() public {
        uint256 amount1 = 10000;
        uint256 amount2 = 22500;
        uint256 amount3 = 32500;
        bytes32 id1 = keccak256("0x01");
        bytes32 id2 = keccak256("0x02");
        bytes32 id3 = keccak256("0x03");

        vm.startPrank(payer1);
        testToken.approve(address(multicall), amount3);
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](3);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount1,
            id: id1
        });
        arr[1] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount2,
            id: id2
        });
        arr[2] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(testToken),
            receiver: receiver1,
            payer: payer1,
            amount: amount3,
            id: id3
        });
        multicall.multipay{value: amount1 + amount2}(arr);
        vm.stopPrank();

        assertEq(getBalance(address(multicall), true), 0);
        assertEq(getBalance(address(multicall), false), 0);

        assertEq(getBalance(address(escrow1), true), amount3);
        assertEq(getBalance(address(escrow1), false), amount1 + amount2);
    }

    function testMulticallToInvalidEscrow() public {
        uint256 amount = 10000;
        bytes32 id = keccak256("0x01");

        vm.startPrank(payer1);
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(multicall),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount,
            id: id
        });
        vm.expectRevert();
        multicall.multipay{value: amount}(arr);
        vm.stopPrank();

        vm.startPrank(payer1);
        testToken.approve(address(multicall), amount);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(multicall),
            currency: address(testToken),
            receiver: receiver1,
            payer: payer1,
            amount: amount,
            id: id
        });
        vm.expectRevert();
        multicall.multipay(arr);
        vm.stopPrank();
    }

    function testMulticallWithInsufficientTokenAmount() public {
        uint256 amount = 10000;
        bytes32 id = keccak256("0x01");

        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(testToken),
            receiver: receiver1,
            payer: payer1,
            amount: amount,
            id: id
        });

        vm.startPrank(payer1);
        vm.expectRevert();
        multicall.multipay(arr);
        vm.stopPrank();
    }

    function testZeroAmountPaymentReverts() public {
        bytes32 paymentId = keccak256("zeroAmount");
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: 0,
            id: paymentId
        });

        vm.startPrank(payer1);
        vm.expectRevert("PaymentFailure");
        multicall.multipay(arr);
        vm.stopPrank();
    }

    function testNonTokenCurrencyReverts() public {
        FailingToken failingToken = new FailingToken();

        bytes32 paymentId = keccak256("nonTokenCurrency");
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(failingToken), 
            receiver: receiver1,
            payer: payer1,
            amount: 10000,
            id: paymentId
        });

        failingToken.setFailTransfers(true);

        vm.startPrank(payer1);
        vm.expectRevert("TokenTransferFailed");
        multicall.multipay(arr);
        vm.stopPrank();
    }

    function testEscrowRevertsOnPlacePayment() public {
        // contract that reverts on any call
        address revertingContract = address(new RevertingEscrowMock());
        
        bytes32 paymentId = keccak256("escrowReverts");
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: revertingContract,
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: 1000,
            id: paymentId
        });

        vm.startPrank(payer1);
        vm.expectRevert("PaymentFailure");
        multicall.multipay{value: 1000}(arr);
        vm.stopPrank();
    }

    function testEscrowRevertsOnPlacePaymentNonNative() public {
        // contract that reverts on any call
        address revertingContract = address(new RevertingEscrowMock());
        
        bytes32 paymentId = keccak256("escrowReverts");
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: revertingContract,
            currency: address(testToken),
            receiver: receiver1,
            payer: payer1,
            amount: 1000,
            id: paymentId
        });

        vm.startPrank(payer1);
        testToken.approve(address(multicall), 1000);
        vm.expectRevert("TokenPaymentFailure");
        multicall.multipay(arr);
        vm.stopPrank();
    }

    function testOverpayingNativeCurrencyDoesNotRevert() public {
        // test overpaying with native currency. this doesnt revert but prrobably should

        uint256 overpayAmount = 20000;
        uint256 requiredAmount = 10000;
        bytes32 paymentId = keccak256("overpayingTest");

        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: requiredAmount,
            id: paymentId
        });

        uint256 initialBalance = payer1.balance;
        vm.startPrank(payer1);
        multicall.multipay{value: overpayAmount}(arr);
        vm.stopPrank();

        Payment memory payment = escrow.getPayment(paymentId);
        assertEq(payment.amount, requiredAmount);

        // The payers balance should decrease by the overpayAmount
        uint256 newBalance = payer1.balance;
        assertEq(newBalance, initialBalance - overpayAmount, "Overpayment should be deducted from sender");

        // The escrow contract should have the full overpayAmount
        assertEq(address(escrow).balance, requiredAmount, "Escrow holds only required amount");
        // The difference should remain in EscrowMulticall contract
        assertEq(address(multicall).balance, overpayAmount - requiredAmount, "Multicall should hold remainder");
    }


    // Event tests

    // events
    event PaymentReceived(
        bytes32 indexed paymentId, address indexed to, address from, address currency, uint256 amount
    );

    event ReleaseAssentGiven( // 1 = payer, 2 = receiver, 3 = arbiter
        bytes32 indexed paymentId,
        address assentingAddress,
        //TODO: make enum
        uint8 assentType
    );

    event EscrowReleased(bytes32 indexed paymentId, uint256 amount, uint256 fee);

    event PaymentTransferred(bytes32 indexed paymentId, address currency, uint256 amount);

    event PaymentTransferFailed(bytes32 indexed paymentId, address currency, uint256 amount);

    function testPaymentReceivedEvent() public {
        // Prepare test data
        bytes32 paymentId = keccak256("payment1");
        address payerAccount = payer1;
        address receiverAccount = receiver1;
        uint256 amount = 1000;
        bool isToken = false;

        // expect PaymentReceived event
        vm.expectEmit(true, true, true, true);
        emit PaymentReceived(paymentId, receiverAccount, payerAccount, address(0), amount);

        // place payment
        placePayment(paymentId, payerAccount, receiverAccount, amount, isToken);
    }

    function testReleaseAssentGivenEvent() public {
        // Setup a payment first
        bytes32 paymentId = keccak256("payment2");
        address payerAccount = payer1;
        address receiverAccount = receiver1;
        uint256 amount = 2000;
        bool isToken = false;
        placePayment(paymentId, payerAccount, receiverAccount, amount, isToken);

        // payer release first
        vm.prank(payerAccount);
        vm.expectEmit(true, true, true, true);
        emit ReleaseAssentGiven(paymentId, payerAccount, 2 /*payer assent*/ );
        escrow.releaseEscrow(paymentId);

        // receiver releases
        vm.prank(receiverAccount);
        vm.expectEmit(true, true, true, true);
        emit ReleaseAssentGiven(paymentId, receiverAccount, 1 /*receiver assent*/ );
        escrow.releaseEscrow(paymentId);
    }

    function testEscrowReleasedEvent() public {
        // Setup a payment and fully release escrow
        bytes32 paymentId = keccak256("payment3");
        address payerAccount = payer1;
        address receiverAccount = receiver1;
        uint256 amount = 3000;
        bool isToken = false;
        placePayment(paymentId, payerAccount, receiverAccount, amount, isToken);

        // Both parties release
        vm.startPrank(payerAccount);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();

        vm.startPrank(receiverAccount);

        vm.expectEmit(true, true, true, true);
        emit EscrowReleased(paymentId, amount, 0);
        escrow.releaseEscrow(paymentId);
        vm.stopPrank();
    }

    function testPaymentTransferredEventOnRelease() public {
        // Setup a payment
        bytes32 paymentId = keccak256("payment4");
        address payerAccount = payer1;
        address receiverAccount = receiver1;
        uint256 amount = 4000;
        bool isToken = false;
        placePayment(paymentId, payerAccount, receiverAccount, amount, isToken);

        // Both parties assent to release to trigger transfer
        vm.prank(payerAccount);
        escrow.releaseEscrow(paymentId);

        vm.prank(receiverAccount);
        // Expect transfer of funds to receiver
        vm.expectEmit(true, true, true, true);
        emit PaymentTransferred(paymentId, address(0), amount);
        escrow.releaseEscrow(paymentId);
    }

    function testPaymentTransferredEventOnRefund() public {
        // Setup payment
        bytes32 paymentId = keccak256("payment5");
        address payerAccount = payer1;
        address receiverAccount = receiver1;
        uint256 amount = 5000;
        bool isToken = false;
        placePayment(paymentId, payerAccount, receiverAccount, amount, isToken);

        uint256 refundAmount = 1000;

        // Receiver refunds
        vm.prank(receiverAccount);
        vm.expectEmit(true, true, true, true);
        emit PaymentTransferred(paymentId, address(0), refundAmount);
        escrow.refundPayment(paymentId, refundAmount);
    }

    function testPaymentTransferFailedEvent() public {
        FailingToken failingToken = new FailingToken();

        address payerAccount = payer1;
        address receiverAccount = receiver1;
        uint256 amount = 6000 ether;
        bytes32 paymentId = keccak256("payment6");

        failingToken.transfer(payer1, amount);

        // Mint failing tokens
        vm.prank(payerAccount);
        failingToken.approve(address(multicall), amount);

        // Place payment
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](1);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow),
            currency: address(failingToken),
            id: paymentId,
            receiver: receiverAccount,
            payer: payerAccount,
            amount: amount
        });

        vm.prank(payerAccount);
        multicall.multipay(arr);

        // set the failing token to fail transfers
        vm.prank(address(this));
        failingToken.setFailTransfers(true);

        // payer to release the escrow
        vm.prank(payerAccount);
        escrow.releaseEscrow(paymentId);

        // release the escrow and expect the PaymentTransferFailed event
        vm.expectEmit(true, true, true, true);
        emit PaymentTransferFailed(paymentId, address(failingToken), amount);

        vm.prank(receiverAccount);
        escrow.releaseEscrow(paymentId);
    }

    function testMultipleEventsEmittedForMultiplePayments() public {
        // Setup
        uint256 amount1 = 5000;
        uint256 amount2 = 8000;
        uint256 amount3 = 10000;

        bytes32 id1 = keccak256("batchPayment1");
        bytes32 id2 = keccak256("batchPayment2");
        bytes32 id3 = keccak256("batchPayment3");

        // Approve tokens for the third payment
        vm.startPrank(payer1);
        testToken.approve(address(multicall), amount3);
        vm.stopPrank();

        // prepare three payments: two native one token
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](3);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount1,
            id: id1
        });
        arr[1] = MulticallPaymentInput({
            contractAddress: address(escrow2),
            currency: address(0),
            receiver: receiver2,
            payer: payer1,
            amount: amount2,
            id: id2
        });
        arr[2] = MulticallPaymentInput({
            contractAddress: address(escrow3),
            currency: address(testToken),
            receiver: receiver3,
            payer: payer1,
            amount: amount3,
            id: id3
        });

        // Expect three PaymentReceived events, one per payment
        vm.expectEmit(true, true, true, true);
        emit PaymentReceived(id1, receiver1, payer1, address(0), amount1);
        vm.expectEmit(true, true, true, true);
        emit PaymentReceived(id2, receiver2, payer1, address(0), amount2);
        vm.expectEmit(true, true, true, true);
        emit PaymentReceived(id3, receiver3, payer1, address(testToken), amount3);

        // execute the multipay
        vm.prank(payer1);
        multicall.multipay{value: amount1 + amount2}(arr);
    }

    function testNoEventsEmittedOnBatchFailure() public {
        // Setup
        uint256 amount1 = 5000;
        uint256 amount2 = 10000; // This will cause a failure
        bytes32 id1 = keccak256("failingBatch1");
        bytes32 id2 = keccak256("failingBatch2");

        // For token payment do not approve enough tokens so failure is triggered
        vm.startPrank(payer1);
        // only approve less than needed
        testToken.approve(address(multicall), amount2 - 1);
        vm.stopPrank();

        // two payments: one native one token
        MulticallPaymentInput[] memory arr = new MulticallPaymentInput[](2);
        arr[0] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(0),
            receiver: receiver1,
            payer: payer1,
            amount: amount1,
            id: id1
        });
        arr[1] = MulticallPaymentInput({
            contractAddress: address(escrow1),
            currency: address(testToken),
            receiver: receiver1,
            payer: payer1,
            amount: amount2,
            id: id2
        });

        // the entire multipay should revert do to insufficient token approval
        vm.startPrank(payer1);
        vm.expectRevert();
        multicall.multipay{value: amount1}(arr);
        vm.stopPrank();
    }
    
}

contract RevertingEscrowMock {
    function placePayment(PaymentInput calldata) external payable {
        revert("Mocked Revert in placePayment");
    }
}

