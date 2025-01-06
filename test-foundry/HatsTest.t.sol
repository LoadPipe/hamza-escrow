// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

// Hats Protocol
import "hats-protocol/src/Hats.sol";

// Local imports
import { HatsSecurityContext } from "../src/HatsSecurityContext.sol";
import { PaymentEscrow, IEscrowContract } from "../src/PaymentEscrow.sol";
import { SystemSettings } from "../src/SystemSettings.sol";
import { TestToken } from "../src/TestToken.sol";
import { ISecurityContext } from "../src/ISecurityContext.sol";
import { ISystemSettings } from "../src/ISystemSettings.sol";
import { PaymentInput, Payment } from "../src/PaymentInput.sol";
import { FailingToken } from "../src/FailingToken.sol";

// For reference, these roles are defined in HasSecurityContext:
bytes32 constant ADMIN_ROLE   = 0x00; // 0x0 (by convention)
bytes32 constant PAUSER_ROLE  = keccak256("PAUSER_ROLE");
bytes32 constant SYSTEM_ROLE  = keccak256("SYSTEM_ROLE");
bytes32 constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
bytes32 constant DAO_ROLE     = keccak256("DAO_ROLE");

/**
 * @title PaymentEscrowHatsTest
 *
 * Demonstrates how to test PaymentEscrow using the HatsSecurityContext for role-based checks.
 * This file shows only a subset of tests for brevity, but you can replicate the rest
 * of your original test logic as desired.
 */
contract PaymentEscrowHatsTest is Test {
    // -------------------------------------------------------
    // Instance variables
    // -------------------------------------------------------
    Hats public hats; 
    HatsSecurityContext public hatsSecurityContext;
    PaymentEscrow public escrow;
    TestToken public testToken;
    SystemSettings public systemSettings;

    // -------------------------------------------------------
    // Addresses that we will assign hats to
    // -------------------------------------------------------
    address public admin      = address(1);
    address public vault      = address(2);
    address public payer1     = address(3);
    address public receiver1  = address(4);
    address public arbiter    = address(5);
    address public dao        = address(6);
    address public system     = address(7);
    address public nonOwner   = address(8);

    // -------------------------------------------------------
    // Example Hat IDs for each role
    // -------------------------------------------------------
    uint256 public adminHatId   = 1; // each ID in Hats is typically a uint256 
    uint256 public arbiterHatId = 2;
    uint256 public daoHatId     = 3;
    uint256 public systemHatId  = 4;
    uint256 public pauserHatId  = 5; // if we want to test pauser

    // -------------------------------------------------------
    // Setup
    // -------------------------------------------------------
    function setUp() public {
        // 1. Deploy the Hats Protocol base contract
        hats = new Hats();

        // 2. Deploy our HatsSecurityContext. 
        //    We must pass the address of the Hats instance & 
        //    the initial admin Hat ID that controls "ADMIN_ROLE".
        hatsSecurityContext = new HatsSecurityContext(address(hats), adminHatId);

        // 3. The addresses that should "wear" those hats also need to be minted 
        //    the respective hats from the base Hats contract.
        //    We'll do this as the "owner" of the Hats contract (for simplicity).
        //    If your Hats Protocol instance is structured differently, 
        //    adapt these calls as needed.
        hats.mintHat(adminHatId,   admin);
        hats.mintHat(arbiterHatId, arbiter);
        hats.mintHat(daoHatId,     dao);
        hats.mintHat(systemHatId,  system);
        hats.mintHat(pauserHatId,  admin); // example

        // 4. Now, map each bytes32 role to the correct Hat ID. 
        //    By default, only the ADMIN_ROLE can call setRoleHat().
        vm.startPrank(admin);
        hatsSecurityContext.setRoleHat(ARBITER_ROLE, arbiterHatId);
        hatsSecurityContext.setRoleHat(DAO_ROLE,     daoHatId);
        hatsSecurityContext.setRoleHat(SYSTEM_ROLE,  systemHatId);
        hatsSecurityContext.setRoleHat(PAUSER_ROLE,  pauserHatId);
        vm.stopPrank();

        // 5. (Optional) give our test accounts some ETH
        vm.deal(admin,    100 ether);
        vm.deal(payer1,   100 ether);
        vm.deal(receiver1,100 ether);
        vm.deal(arbiter,  100 ether);
        vm.deal(dao,      100 ether);
        vm.deal(system,   100 ether);
        vm.deal(nonOwner, 100 ether);

        // 6. Deploy a test token & mint some tokens to our key addresses
        testToken = new TestToken("XYZ", "ZYX");
        testToken.mint(payer1,    10_000_000_000);
        testToken.mint(receiver1, 10_000_000_000);

        // 7. Deploy a SystemSettings contract that references the Hats-based security context
        systemSettings = new SystemSettings(
            ISecurityContext(address(hatsSecurityContext)), // new context
            vault,        // vault address for fees
            0             // initial feeBps = 0
        );

        // 8. Finally, deploy PaymentEscrow referencing the new Hats security context
        //    & referencing the systemSettings for fees/parameters
        escrow = new PaymentEscrow(
            ISecurityContext(address(hatsSecurityContext)), 
            ISystemSettings(address(systemSettings)), 
            false // autoReleaseFlag
        );
    }

    // -------------------------------------------------------
    // Helpers
    // -------------------------------------------------------
    function _getBalance(address who, bool isToken) internal view returns (uint256) {
        if (isToken) {
            return testToken.balanceOf(who);
        } else {
            return who.balance;
        }
    }

    function _placePayment(
        bytes32 paymentId,
        address payerAccount,
        address receiverAccount,
        uint256 amount,
        bool isToken
    ) internal {
        PaymentInput memory inp = PaymentInput({
            currency: isToken ? address(testToken) : address(0),
            id: paymentId,
            receiver: receiverAccount,
            payer: payerAccount,
            amount: amount
        });

        if (isToken) {
            vm.prank(payerAccount);
            testToken.approve(address(escrow), amount);

            vm.prank(payerAccount);
            escrow.placePayment(inp);
        } else {
            vm.prank(payerAccount);
            escrow.placePayment{ value: amount }(inp);
        }
    }

    // -------------------------------------------------------
    // A few example tests (you can adapt/extend as needed)
    // -------------------------------------------------------

    /**
     * @dev Simple test: verify that the address wearing the ARBITER_ROLE hat 
     *      can call the escrow release on behalf of the payer.
     */
    function testArbiterCanReleaseOnBehalfOfPayer() public {
        // Arrange
        uint256 amount = 1000;
        bytes32 paymentId = keccak256("arbiter-test");

        // Place a token payment from payer1 to receiver1
        _placePayment(paymentId, payer1, receiver1, amount, true);

        // Act
        // 1) receiver releases
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        // 2) Now the arbiter, who has the arbiterHatId, 
        //    is recognized as ARBITER_ROLE via HatsSecurityContext.
        //    The default code is: 
        //      require(hats.isWearerOfHat(msg.sender, roleToHatId[ARBITER_ROLE]), "Caller is not arbiter");
        vm.prank(arbiter);
        escrow.releaseEscrow(paymentId);

        // Assert 
        Payment memory p = escrow.getPayment(paymentId);
        assertTrue(p.released, "Payment should be fully released");
        assertTrue(p.payerReleased, "Arbiter sets payerReleased = true");
        assertTrue(p.receiverReleased, "Receiver has already released");
    }

    /**
     * @dev Demonstrates that an address without the correct Hat
     *      cannot perform an action restricted to that role.
     */
    function testNonArbiterCannotReleaseForPayer() public {
        // Arrange
        uint256 amount = 1000;
        bytes32 paymentId = keccak256("non-arbiter-test");

        _placePayment(paymentId, payer1, receiver1, amount, false);

        // Act & Assert
        // nonOwner does not have ARBITER_ROLE. 
        // The default error from PaymentEscrow is "Unauthorized" 
        // because the role check fails in releaseEscrow.
        vm.prank(nonOwner);
        vm.expectRevert("Unauthorized");
        escrow.releaseEscrow(paymentId);
    }

    /**
     * @dev Example test to show how roles (via Hats) also apply to 
     *      pausing and unpausing.
     */
    function testPausingByAuthorizedHatWearer() public {
        // By default in the code, pausing requires SYSTEM_ROLE.
        // If your code references PAUSER_ROLE, adjust accordingly.

        // Confirm escrow is not paused
        assertFalse(escrow.paused(), "Should not start paused");

        // Attempt to pause as a random address -> revert
        vm.prank(nonOwner);
        vm.expectRevert("Caller is not admin");
        // or if your code is "Caller is not system" or "Unauthorized", adapt
        escrow.pause();

        // Pause with the system role (the systemHatId)
        vm.prank(system);
        escrow.pause();
        assertTrue(escrow.paused(), "Should be paused now");
    }

    /**
     * @dev Minimal example: ensures we can place a Payment with tokens 
     *      and that the correct Hat-based role is enforced if 
     *      we try to modify role mappings on the fly.
     */
    function testModifyRoleHatByAdmin() public {
        // Since setRoleHat requires the caller to wear the ADMIN_ROLE hat,
        // let’s show that only `admin` can do this. 
        // Attempt as a non-admin => revert
        vm.prank(nonOwner);
        vm.expectRevert("Caller is not admin");
        hatsSecurityContext.setRoleHat(ARBITER_ROLE, 999999);

        // Attempt as admin => success
        vm.startPrank(admin);
        hatsSecurityContext.setRoleHat(ARBITER_ROLE, 999999);
        vm.stopPrank();
    }

    /**
     * @dev Simple fee-based test to show the hats integration doesn't break 
     *      normal business logic.
     */
    function testFeesWithHatsContext() public {
        // Setup a 5% fee
        vm.prank(dao);
        systemSettings.setFeeBps(500); // 5%

        bytes32 paymentId = keccak256("fees-test");
        uint256 amount = 10_000;
        uint256 initialVaultBalance = _getBalance(vault, true);
        uint256 initialReceiverBalance = _getBalance(receiver1, true);

        // place payment
        _placePayment(paymentId, payer1, receiver1, amount, true);

        // release from both sides
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        // check final
        Payment memory p = escrow.getPayment(paymentId);
        assertTrue(p.released);

        uint256 expectedFee = (amount * 500) / 10_000; // 5% of 10,000
        assertEq(_getBalance(vault, true), initialVaultBalance + expectedFee);
        assertEq(_getBalance(receiver1, true), initialReceiverBalance + (amount - expectedFee));
    }
}
