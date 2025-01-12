// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { FullEscrowDeployment } from "../scripts/FullEscrowDeployment.s.sol";

// Import the contracts
import { Hats } from "@hats-protocol/Hats.sol";
import { PaymentEscrow } from "../src/PaymentEscrow.sol";
import { EscrowMulticall } from "../src/EscrowMulticall.sol";
import { ISystemSettings } from "../src/ISystemSettings.sol";
import { SystemSettings } from "../src/SystemSettings.sol";
import { HatsSecurityContext } from "../src/HatsSecurityContext.sol";
import { Roles } from "../src/Roles.sol";

import { PaymentInput, Payment } from "../src/PaymentEscrow.sol";
import { MulticallPaymentInput } from "../src/EscrowMulticall.sol";

contract FullSystemIntegrationTest is Test {
    FullEscrowDeployment internal deploymentScript;

    Hats internal hats;
    HatsSecurityContext internal securityContext;
    SystemSettings internal systemSettings;
    PaymentEscrow internal paymentEscrow;
    EscrowMulticall internal escrowMulticall;

    // IDs from the script
    uint256 internal adminHatId;
    uint256 internal arbiterHatId;
    uint256 internal daoHatId;

    address internal adminAddress   = address(0x10);
    address internal vaultAddress   = address(0x11);
    address internal arbiterAddress = address(0x12);
    address internal daoAddress     = address(0x13);

    function setUp() public {
        // 1) Create and run the script
        deploymentScript = new FullEscrowDeployment();
        deploymentScript.run();

        // 2) Retrieve the references from the script’s public variables
        hats = deploymentScript.hats();
        securityContext = deploymentScript.securityContext();
        systemSettings = deploymentScript.systemSettings();
        paymentEscrow = deploymentScript.paymentEscrow();
        escrowMulticall = deploymentScript.escrowMulticall();

        adminHatId = deploymentScript.adminHatId();
        arbiterHatId = deploymentScript.arbiterHatId();
        daoHatId = deploymentScript.daoHatId();
    }

    // test that the script minted a top hat for the admin
    function testAdminHatMinted() public {
        // The admin hat ID should have minted to adminAddress
        bool isWearer = hats.isWearerOfHat(adminAddress, adminHatId);
        assertTrue(isWearer, "Admin address should wear the top hat");
    }

    // test that ARBITER_ROLE is mapped to the correct hat
    function testArbiterHatMapping() public {
        uint256 actual = securityContext.roleToHatId(Roles.ARBITER_ROLE);
        assertEq(actual, arbiterHatId, "Arbiter role should match arbiterHatId from script");
    }

    // test that system settings can be updated by the DAO hat
    function testDaoCanSetFeeBps() public {
        // confirm the default is 0
        uint256 oldFee = systemSettings.feeBps();
        assertEq(oldFee, 0, "Default feeBps should be 0");

        vm.startPrank(daoAddress);

        systemSettings.setFeeBps(500); // set to 5%
        vm.stopPrank();

        uint256 newFee = systemSettings.feeBps();
        assertEq(newFee, 500, "FeeBps should be updated by DAO");
    }

    // test PaymentEscrow placePayment
    function testPlacePayment() public {

        // Payer = address(0x30), Receiver = address(0x40)
        address payer    = address(0x30);
        address receiver = address(0x40);

        vm.deal(payer, 1 ether); 

        // Place a payment
        bytes32 paymentId = keccak256("sample-payment");
        uint256 amount    = 0.1 ether;

        vm.startPrank(payer);
        paymentEscrow.placePayment{value: amount}(
            PaymentInput({
                currency: address(0),       // native
                id: paymentId,
                receiver: receiver,
                payer: payer,
                amount: amount
            })
        );
        vm.stopPrank();

        // Check the Payment details
        Payment memory p = paymentEscrow.getPayment(paymentId);
        assertEq(p.id, paymentId);
        assertEq(p.receiver, receiver);
        assertEq(p.payer, payer);
        assertEq(p.amount, amount);
        assertEq(address(paymentEscrow).balance, amount, "Escrow should hold the funds now");
    }

    // test using escrowMulticall
    function testEscrowMulticallSinglePayment() public {
        address payer    = address(0x50);
        address receiver = address(0x60);

        vm.deal(payer, 5 ether);

        // prepare a single payment input
        bytes32 paymentId = keccak256("multicall-payment");
        uint256 amount    = 1 ether;
        MulticallPaymentInput[] memory inputs = new MulticallPaymentInput[](1);
        inputs[0] = MulticallPaymentInput({
            contractAddress: address(paymentEscrow),
            currency: address(0),
            id: paymentId,
            receiver: receiver,
            payer: payer,
            amount: amount
        });

        // call multipay
        vm.startPrank(payer);
        escrowMulticall.multipay{value: amount}(inputs);
        vm.stopPrank();

        // verify the escrow holds the payment
        Payment memory p = paymentEscrow.getPayment(paymentId);
        assertEq(p.amount, amount, "Should store correct payment amount");
        assertEq(p.currency, address(0), "Should be native currency");
        assertEq(address(paymentEscrow).balance, amount, "Escrow holds the funds");
    }

}
