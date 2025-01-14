// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
// optionally import console for debugging
// import "forge-std/console.sol";

import "../src/hats/EligibilityModule.sol";



/**
 * @title EligibilityModuleTest
 * @notice A Foundry test suite for the EligibilityModule contract.
 */
contract EligibilityModuleTest is Test {
    // The contract under test
    EligibilityModule public eligibility;

    // Test addresses
    address public admin    = address(1);
    address public nonAdmin = address(2);

    // Event to listen for
    event HatRulesUpdated(uint256 indexed hatId, bool eligible, bool standing);

    function setUp() public {
        // Deploy the module with `admin` as the initial admin
        eligibility = new EligibilityModule(admin);
    }

    /**
     * @dev Test that the constructor sets the correct admin address.
     */
    function testConstructorSetsAdmin() public {
        assertEq(eligibility.admin(), admin, "Admin should be set to the address passed in constructor");
    }

    /**
     * @dev Test that only the admin can call setHatRules.
     */
    function testOnlyAdminCanSetHatRules() public {
        uint256 hatId = 100;
        // Attempt to set rules as a non-admin
        vm.prank(nonAdmin);
        vm.expectRevert("Not module admin");
        eligibility.setHatRules(hatId, true, true);

        // Now do it as the admin => should succeed
        vm.prank(admin);
        eligibility.setHatRules(hatId, true, false);

        (uint256 eligible, uint256 standing) = eligibility.getWearerStatus(nonAdmin, hatId);
        assertEq(eligible, 1, "Should be eligible");
        assertEq(standing, 0, "Should not be in good standing");
    }

    /**
     * @dev Test that getWearerStatus returns 0,0 (ineligible and bad standing)
     *      if no rules have been set for the hat.
     */
    function testDefaultStatusForUnsetHat() public {
        // We haven't set any rules for hatId = 999 yet
        (uint256 eligible, uint256 standing) = eligibility.getWearerStatus(address(10), 999);

        // By default, eligible = 0, standing = 0
        assertEq(eligible, 0, "Default eligibility should be 0");
        assertEq(standing, 0, "Default standing should be 0");
    }

    /**
     * @dev Test that setting hat rules updates the contract storage and
     *      that getWearerStatus returns correct values.
     */
    function testSetHatRulesUpdatesCorrectly() public {
        uint256 hatId = 42;

        // Admin sets hat rules: eligible = true, standing = true
        vm.startPrank(admin);
        eligibility.setHatRules(hatId, true, true);
        vm.stopPrank();

        (uint256 eligible, uint256 standing) = eligibility.getWearerStatus(nonAdmin, hatId);
        assertEq(eligible, 1, "Should be eligible after setting rules");
        assertEq(standing, 1, "Should be in good standing after setting rules");

        // Change them again: eligible = false, standing = true
        vm.startPrank(admin);
        eligibility.setHatRules(hatId, false, true);
        vm.stopPrank();

        (eligible, standing) = eligibility.getWearerStatus(nonAdmin, hatId);
        assertEq(eligible, 0, "Should now be ineligible");
        assertEq(standing, 1, "Should remain in good standing");
    }

    /**
     * @dev Test that an event is emitted whenever a hat's rules are updated.
     */
    function testSetHatRulesEmitsEvent() public {
        uint256 hatId = 123;
        bool newEligible = true;
        bool newStanding = true;

        vm.startPrank(admin);

        // Expect the HatRulesUpdated event
        vm.expectEmit(true, true, true, true);
        emit HatRulesUpdated(hatId, newEligible, newStanding);

        eligibility.setHatRules(hatId, newEligible, newStanding);
        vm.stopPrank();
    }

    /**
     * @dev Test that only the admin can transfer admin rights to a new address.
     */
    function testOnlyAdminCanTransferAdmin() public {
        // Attempt to transfer admin as non-admin => revert
        vm.prank(nonAdmin);
        vm.expectRevert("Not module admin");
        eligibility.transferAdmin(nonAdmin);

        // Transfer admin as current admin => success
        vm.prank(admin);
        eligibility.transferAdmin(nonAdmin);
        assertEq(eligibility.admin(), nonAdmin, "Admin should be transferred to nonAdmin");
    }

    /**
     * @dev Test that transferring admin to the zero address reverts.
     */
    function testCannotTransferAdminToZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert("Zero address");
        eligibility.transferAdmin(address(0));
        vm.stopPrank();

        // Ensure admin didn't change
        assertEq(eligibility.admin(), admin, "Admin should remain unchanged after failed transfer");
    }

    /**
     * @dev Demonstrate that after transferring admin the new admin can set rules
     *      and the old admin can no longer do so.
     */
    function testNewAdminCanSetHatRules() public {
        uint256 hatId = 1;

        // 1) Transfer admin rights to nonAdmin
        vm.startPrank(admin);
        eligibility.transferAdmin(nonAdmin);
        vm.stopPrank();

        // 2) nonAdmin is the new admin. They can set hat rules
        vm.prank(nonAdmin);
        eligibility.setHatRules(hatId, true, false);

        (uint256 eligible, uint256 standing) = eligibility.getWearerStatus(address(10), hatId);
        assertEq(eligible, 1, "Should be eligible (set by new admin)");
        assertEq(standing, 0, "Should be in bad standing (set by new admin)");

        // 3) The old admin tries to set rules => revert
        vm.prank(admin);
        vm.expectRevert("Not module admin");
        eligibility.setHatRules(hatId, false, false);
    }

    /**
     * @dev test a scenario to ensure 
     *      the module behaves as expected across multiple hats and addresses.
     */
    function testMultipleHatsAndWearers() public {
        // Set rules for two different hats
        uint256 hatIdA = 111;
        uint256 hatIdB = 222;

        // Admin sets different rules
        vm.startPrank(admin);
        eligibility.setHatRules(hatIdA, true, false);  // (eligible = true, standing = false)
        eligibility.setHatRules(hatIdB, false, true);  // (eligible = false, standing = true)
        vm.stopPrank();

        // Check WearerStatus for an arbitrary address
        (uint256 eligA, uint256 standA) = eligibility.getWearerStatus(address(10), hatIdA);
        assertEq(eligA, 1, "hatIdA should be eligible");
        assertEq(standA, 0, "hatIdA should be in bad standing");

        (uint256 eligB, uint256 standB) = eligibility.getWearerStatus(address(10), hatIdB);
        assertEq(eligB, 0, "hatIdB should be ineligible");
        assertEq(standB, 1, "hatIdB should be in good standing");
    }
}
