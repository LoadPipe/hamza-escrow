// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../lib/hats-protocol/src/Hats.sol";

import { HatsSecurityContext } from "../src/HatsSecurityContext.sol";
import { PaymentEscrow, IEscrowContract } from "../src/PaymentEscrow.sol";
import { SystemSettings } from "../src/SystemSettings.sol";
import { TestToken } from "../src/TestToken.sol";
import { IHatsSecurityContext } from "../src/IHatsSecurityContext.sol";
import { ISystemSettings } from "../src/ISystemSettings.sol";
import { PaymentInput, Payment } from "../src/PaymentInput.sol";
import { FailingToken } from "../src/FailingToken.sol";
import { console } from "forge-std/console.sol";

// Dummy Eligibility and Toggle Modules
contract DummyEligibilityModule {
    // Storage to dynamically control eligibility and standing
    bool public isEligible; // Controls eligibility
    bool public isInGoodStanding; // Controls standing

    // Allow updating eligibility dynamically
    function setEligibility(bool _isEligible) external {
        isEligible = _isEligible;
    }

    // Allow updating standing dynamically
    function setStanding(bool _isInGoodStanding) external {
        isInGoodStanding = _isInGoodStanding;
    }

    // Return eligibility and standing dynamically based on storage variables
    function getWearerStatus(address, uint256)
        external
        view
        returns (uint256 eligible, uint256 standing)
    {
        // Convert bool to uint256: true = 1, false = 0
        eligible = isEligible ? 1 : 0;
        standing = isInGoodStanding ? 1 : 0;
    }
}


contract DummyToggleModule {
    address public immutable admin;
    bool public globalActive; // if false => all hats that use this module are inactive

    constructor(address _admin) {
        admin = _admin;
        globalActive = true; // default to active
    }

    function setStatus(bool _status) external {
        require(msg.sender == admin, "Not the admin");
        globalActive = _status;
    }

    // The Hats contract calls `getHatStatus(uint256)` to check whether a hat is active.
    // Return `1` for active, `0` for inactive, ignoring the specific hatId.
    function getHatStatus(uint256) external view returns (uint256) {
        return globalActive ? 1 : 0;
    }
}

// roles in roles.sol for refrence 
bytes32 constant ADMIN_ROLE   = 0x00; 
bytes32 constant PAUSER_ROLE  = keccak256("PAUSER_ROLE");
bytes32 constant SYSTEM_ROLE  = keccak256("SYSTEM_ROLE");
bytes32 constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
bytes32 constant DAO_ROLE     = keccak256("DAO_ROLE");

/**
 * @title PaymentEscrowHatsTest
 *
 * Demonstrates how to test PaymentEscrow using the HatsSecurityContext for role-based checks
 */
contract PaymentEscrowHatsTest is Test {
    Hats public hats; 
    HatsSecurityContext public hatsSecurityContext;
    PaymentEscrow public escrow;
    TestToken public testToken;
    SystemSettings public systemSettings;

    DummyEligibilityModule public eligibilityModule;
    DummyToggleModule public toggleModule;

    // Hats address and roles
    address public admin      = address(1);
    address public vault      = address(2);
    address public payer1     = address(3);
    address public receiver1  = address(4);
    address public arbiter    = address(5);
    address public dao        = address(6);
    address public system     = address(7);
    address public nonOwner   = address(8);

    // Hat IDs
    uint256 public adminHatId; 
    uint256 public arbiterHatId;
    uint256 public daoHatId;
    uint256 public systemHatId;
    uint256 public pauserHatId;


    function setUp() public {
        // 1. Deploy the Hats Protocol base contract
        hats = new Hats("TestHats", "https://example.com/hats/");

        // 2. Deploy dummy eligibility and toggle modules
        eligibilityModule = new DummyEligibilityModule();
        eligibilityModule.setEligibility(true); // Set initial eligibility to true
        eligibilityModule.setStanding(true); // Set initial standing to true
        toggleModule = new DummyToggleModule(admin);

        // 3. Create the top hat
        adminHatId = hats.mintTopHat(admin, "admin hat","https://example.com/hats/admin.png");

        vm.startPrank(admin);

        // 4. Create child hats
        arbiterHatId = hats.createHat(
            adminHatId, // Admin of Arbiter Hat
            "Arbiter Hat", // Details about the hat
            2, // Max supply of 1
            address(eligibilityModule), // Eligibility module
            address(toggleModule), // Toggle module
            true, // Mutable
            "https://example.com/hats/arbiter.png" // Image URI
        );


        daoHatId = hats.createHat(
            adminHatId, // Admin of DAO Hat
            "DAO Hat", // Details about the hat
            2, // Max supply of 1
            address(eligibilityModule), // Eligibility module
            address(toggleModule), // Toggle module
            true, // Mutable
            "https://example.com/hats/dao.png" // Image URI
        );



        systemHatId = hats.createHat(
            adminHatId, // Admin of System Hat
            "System Hat", // Details about the hat
            2, // Max supply of 1
            address(eligibilityModule), // Eligibility module
            address(toggleModule), // Toggle module
            true, // Mutable
            "https://example.com/hats/system.png" // Image URI
        );

        pauserHatId = hats.createHat(
            adminHatId, // Admin of Pauser Hat
            "Pauser Hat", // Details about the hat
            2, // Max supply of 1
            address(eligibilityModule), // Eligibility module
            address(toggleModule), // Toggle module
            true, // Mutable
            "https://example.com/hats/pauser.png" // Image URI
        );


        // 5. Deploy our HatsSecurityContext with the Hats instance & the initial admin Hat ID
        hatsSecurityContext = new HatsSecurityContext(address(hats), adminHatId);

        // 6. Mint hats to the respective addresses
        hats.mintHat(arbiterHatId, arbiter);
        hats.mintHat(daoHatId, dao);
        hats.mintHat(systemHatId, system);
        hats.mintHat(pauserHatId, admin);

        // 7. Map each bytes32 role to the correct Hat ID
        hatsSecurityContext.setRoleHat(ARBITER_ROLE, arbiterHatId);
        hatsSecurityContext.setRoleHat(DAO_ROLE, daoHatId);
        hatsSecurityContext.setRoleHat(SYSTEM_ROLE, systemHatId);
        hatsSecurityContext.setRoleHat(PAUSER_ROLE, pauserHatId);
        vm.stopPrank();

        // 8. (Optional) give our test accounts some ETH
        vm.deal(admin, 100 ether);
        vm.deal(payer1, 100 ether);
        vm.deal(receiver1, 100 ether);
        vm.deal(arbiter, 100 ether);
        vm.deal(dao, 100 ether);
        vm.deal(system, 100 ether);
        vm.deal(nonOwner, 100 ether);

        // 9. Deploy a test token & mint some tokens to our key addresses
        testToken = new TestToken("XYZ", "ZYX");
        testToken.mint(payer1, 10_000_000_000);
        testToken.mint(receiver1, 10_000_000_000);

        // 10. Deploy SystemSettings
        vm.startPrank(admin);
        systemSettings = new SystemSettings(
            IHatsSecurityContext(address(hatsSecurityContext)),
            vault, // Vault address
            0 // Initial fee BPS
        );

        // 11. Deploy PaymentEscrow
        escrow = new PaymentEscrow(
            IHatsSecurityContext(address(hatsSecurityContext)),
            ISystemSettings(address(systemSettings)),
            false // autoReleaseFlag
        );

        vm.stopPrank();
    }

    //helper functions
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

        // 2) The arbiter, wearing the arbiterHatId, 
        //    releases on behalf of payer
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
        vm.prank(nonOwner);
        vm.expectRevert("Unauthorized");
        escrow.releaseEscrow(paymentId);
    }

    /**
     * @dev Example test to show how roles (via Hats) also apply to 
     *      pausing and unpausing.
     */
    function testPausingByAuthorizedHatWearer() public {

        assertFalse(escrow.paused(), "Should not start paused");

        // Attempt to pause as a random address -> revert
        vm.prank(nonOwner);
        vm.expectRevert();
        escrow.pause();

        // Pause with the systemHatId 
        vm.prank(system);
        escrow.pause();
        assertTrue(escrow.paused(), "Should be paused now");
    }

    /**
     * @dev Minimal example: ensures we can place a Payment with tokens 
     *      and that the correct Hat-based role is enforced 
     *      if we try to modify role mappings on the fly.
     */
    function testModifyRoleHatByAdmin() public {
        // Attempt as non-admin => revert
        vm.prank(nonOwner);
        vm.expectRevert("Caller is not admin");
        hatsSecurityContext.setRoleHat(ARBITER_ROLE, 999999);

        // Attempt as admin => success
        vm.startPrank(admin);
        hatsSecurityContext.setRoleHat(ARBITER_ROLE, 999999);
        vm.stopPrank();
    }

    /**
     * @dev Simple fee-based test to show the hats integration 
     *      doesn't break normal business logic.
     */
    function testFeesWithHatsContext() public {
        // Setup a 5% fee
        vm.prank(dao);
        systemSettings.setFeeBps(500); // 5%

        bytes32 paymentId = keccak256("fees-test");
        uint256 amount = 10_000;
        uint256 initialVaultBalance = _getBalance(vault, true);
        uint256 initialReceiverBalance = _getBalance(receiver1, true);

        _placePayment(paymentId, payer1, receiver1, amount, true);

        // release from both sides
        vm.prank(payer1);
        escrow.releaseEscrow(paymentId);
        vm.prank(receiver1);
        escrow.releaseEscrow(paymentId);

        Payment memory p = escrow.getPayment(paymentId);
        assertTrue(p.released);

        uint256 expectedFee = (amount * 500) / 10_000; // 5% of 10,000
        assertEq(_getBalance(vault, true), initialVaultBalance + expectedFee);
        assertEq(_getBalance(receiver1, true), initialReceiverBalance + (amount - expectedFee));
    }

    function testUnauthorizedCannotMintHat() public {
        address testAddress = address(9); // Random test address
        uint256 testHatId = arbiterHatId; // Arbiter Hat ID

        // Act & Assert
        vm.prank(testAddress); // Simulate an unauthorized user
        vm.expectRevert();
        hats.mintHat(testHatId, testAddress);
    }

    function testAdminMintsHat() public {
        address testAddress = address(9); // Random test address
        uint256 testHatId = arbiterHatId; // Arbiter Hat ID

        vm.startPrank(admin);
        hats.mintHat(testHatId, testAddress);
        vm.stopPrank();

        assertTrue(hats.isWearerOfHat(testAddress, testHatId), "Test address should now own the hat");
    }

    function testIneligibleCannotMintHat() public {
        address testAddress = address(9); // Random test address
        uint256 testHatId = arbiterHatId; // Arbiter Hat ID

        // Set the eligibility to false (ineligible)
        eligibilityModule.setEligibility(false);

        // Act & Assert
        vm.prank(admin); // Admin attempts to mint the hat to the test address
        vm.expectRevert(); // Revert expected due to ineligibility
        hats.mintHat(testHatId, testAddress);

        // Ensure the hat was not minted
        assertFalse(hats.isWearerOfHat(testAddress, testHatId), "Test address should not own the hat");
    }

    function testToggleModule_DefaultsToActive() public {
        bool arbiterIsActive = hats.isActive(arbiterHatId);
        assertTrue(arbiterIsActive, "Arbiter Hat should be active by default");

        bool daoIsActive = hats.isActive(daoHatId);
        assertTrue(daoIsActive, "DAO Hat should be active by default");

        bool systemIsActive = hats.isActive(systemHatId);
        assertTrue(systemIsActive, "System Hat should be active by default");
    }

    function testAdminCanToggleAllHatsOff() public {
        // 1) Confirm hats are active initially
        assertTrue(hats.isActive(arbiterHatId), "Should start active");
        assertTrue(hats.isActive(daoHatId), "Should start active");
        assertTrue(hats.isActive(systemHatId), "Should start active");
        assertTrue(hats.isActive(pauserHatId), "Should start active");

        // 2) Admin toggles them off
        vm.startPrank(admin);
        toggleModule.setStatus(false);
        vm.stopPrank();

        // 3) Now all hats referencing this module are inactive
        assertFalse(hats.isActive(arbiterHatId), "Arbiter Hat should be inactive");
        assertFalse(hats.isActive(daoHatId), "DAO Hat should be inactive");
        assertFalse(hats.isActive(systemHatId), "System Hat should be inactive");
        assertFalse(hats.isActive(pauserHatId), "Pauser Hat should be inactive");
    }

    function testNonAdminCannotToggle() public {
        // Attempting to toggle from a non-admin address should revert
        vm.prank(nonOwner);
        vm.expectRevert("Not the admin");
        toggleModule.setStatus(false);

        // Confirm the hats remain active
        assertTrue(hats.isActive(arbiterHatId), "Arbiter Hat should still be active");
        assertTrue(hats.isActive(daoHatId), "DAO Hat should still be active");
    }

    function testCannotMintWhenHatsToggledOff() public {
        // 1) Admin toggles off
        vm.startPrank(admin);
        toggleModule.setStatus(false);
        vm.stopPrank();

        // 2) attempt to mint any hat should revert with HatNotActive
        vm.startPrank(admin);
        vm.expectRevert();
        hats.mintHat(daoHatId, address(9));
        vm.stopPrank();

        // Confirm the user did not receive the hat
        assertFalse(hats.isWearerOfHat(address(9), daoHatId), "Should not be minted when inactive");
    }

    function testCanReToggleOnAndMintAgain() public {
        // 1) Admin toggles off then on again
        vm.startPrank(admin);
        toggleModule.setStatus(false);
        toggleModule.setStatus(true);
        vm.stopPrank();

        // 2) Attempt to mint => should succeed now
        vm.startPrank(admin);
        hats.mintHat(daoHatId, address(9));
        vm.stopPrank();

        // Confirm the user now has the hat
        assertTrue(hats.isWearerOfHat(address(9), daoHatId), "Should be minted after reactivating");
    }


}
