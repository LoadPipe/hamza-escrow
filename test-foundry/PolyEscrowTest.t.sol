// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {PolyEscrow, PaymentInput} from "../src/PolyEscrow.sol";
import {SecurityContext} from "../src/SecurityContext.sol";
import {SystemSettings} from "../src/SystemSettings.sol";
import {TestToken} from "../src/test-contracts/TestToken.sol";
import {ISecurityContext} from "../src/interfaces/ISecurityContext.sol";
import {console} from "forge-std/console.sol";
import {FailingToken} from "../src/test-contracts/FailingToken.sol";

contract PaymentEscrowTest is Test {
    SecurityContext internal securityContext;
    SystemSettings internal systemSettings;
    PolyEscrow internal escrow;
    TestToken internal testToken;

    address internal admin;
    address internal nonOwner;
    address internal payer1;
    address internal payer2;
    address internal receiver1;
    address internal receiver2;
    address internal vaultAddress;
    address internal arbiter1;
    address internal arbiter2;
    address internal dao;
    address internal system;

    // Hat IDs
    uint256 internal adminHatId;
    uint256 internal arbiterHatId;
    uint256 internal daoHatId;
    uint256 internal systemHatId;

    bytes32 internal constant SYSTEM_ROLE = keccak256("SYSTEM_ROLE");
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address internal adminAddress1 = 0x1542612fee591eD35C05A3E980bAB325265c06a3;

    // Add storage variables for commonly used test values
    uint256 internal testAmount;
    bytes32 internal testPaymentId;
    uint256[] internal balanceSnapshot;

    function setUp() public {
        admin = address(1);
        nonOwner = address(2);
        vaultAddress = address(3);
        payer1 = address(4);
        payer2 = address(5);
        receiver1 = address(6);
        receiver2 = address(7);
        arbiter1 = address(8);
        arbiter2 = address(9);
        dao = address(9);
        system = address(10);

        vm.deal(admin, 100 ether);
        vm.deal(nonOwner, 100 ether);
        vm.deal(payer1, 100 ether);
        vm.deal(payer2, 100 ether);
        vm.deal(receiver1, 100 ether);
        vm.deal(receiver2, 100 ether);

        
        vm.startPrank(admin);
        

        // Deploy securityContext
        securityContext = new SecurityContext(adminAddress1);
        systemSettings = new SystemSettings(
            ISecurityContext(address(securityContext)),
            vaultAddress,
            0 // feeBps (0 for now)
        );
        
        testToken = new TestToken("XYZ", "ZYX");
        escrow = new PolyEscrow(ISecurityContext(securityContext), systemSettings);

        testToken.mint(nonOwner, 10_000_000_000);
        testToken.mint(payer1, 10_000_000_000);
        testToken.mint(payer2, 10_000_000_000);
        vm.stopPrank();

        // Initialize test values
        testAmount = 1 ether;
        testPaymentId = keccak256("test-payment");
    }

    //Test that can deploy contract

    //Test that security context is as we set it 

    //Test that security context can be changed 

    //Test that an escrow can be created with properties 

    //Test that an escrow can be released by payer and receiver 

    //Test that an escrow can be released by arbiter

    //Test that an escrow can be refunded by receiver

    //Test that an escrow can be paid in multiple installments 


    // EVENTS 


}