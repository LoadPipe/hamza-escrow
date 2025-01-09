// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/hats/ToggleModule.sol";

/**
 * @title ToggleModuleTest
 * @notice Foundry test suite for the ToggleModule contract
 */
contract ToggleModuleTest is Test {
    ToggleModule public toggleModule;

    // Test addresses
    address public admin    = address(1);
    address public nonAdmin = address(2);

    // Event to listen for
    event HatToggled(uint256 indexed hatId, bool newStatus);

    // Sample hat IDs
    uint256 constant HAT_ID_A = 111;
    uint256 constant HAT_ID_B = 222;

    function setUp() public {
        // Deploy ToggleModule with `admin` as the initial admin
        toggleModule = new ToggleModule(admin);
    }

    /**
     * @dev Ensures the constructor sets the correct admin.
     */
    function testConstructorSetsAdmin() public {
        assertEq(toggleModule.admin(), admin, "Admin should match the address passed to the constructor");
    }

    /**
     * @dev Tests that only the admin can set a hat’s status.
     */
    function testOnlyAdminCanSetHatStatus() public {
        // Attempt to set the hat status from a non-admin => revert
        vm.prank(nonAdmin);
        vm.expectRevert("Not toggle admin");
        toggleModule.setHatStatus(HAT_ID_A, true);

        // Set the hat status as admin => success
        vm.prank(admin);
        toggleModule.setHatStatus(HAT_ID_A, true);

        // Verify the state update
        (uint256 status) = toggleModule.getHatStatus(HAT_ID_A);
        assertEq(status, 1, "Hat should be active after admin sets it");
    }

    /**
     * @dev Tests that the HatToggled event is emitted when a hat’s status is set.
     */
    function testSetHatStatusEmitsEvent() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit HatToggled(HAT_ID_A, true);

        toggleModule.setHatStatus(HAT_ID_A, true);
        vm.stopPrank();
    }

    /**
     * @dev Tests that `getHatStatus` returns the correct value (1 for active, 0 for inactive).
     */
    function testGetHatStatusReturnsCorrectValue() public {
        // 1) Set hat inactive explicitly, check status
        vm.startPrank(admin);
        toggleModule.setHatStatus(HAT_ID_A, false);
        vm.stopPrank();

        uint256 statusA = toggleModule.getHatStatus(HAT_ID_A);
        assertEq(statusA, 0, "Hat should be inactive (0)");

        // 2) Set hat active, check again
        vm.startPrank(admin);
        toggleModule.setHatStatus(HAT_ID_A, true);
        vm.stopPrank();

        statusA = toggleModule.getHatStatus(HAT_ID_A);
        assertEq(statusA, 1, "Hat should be active (1)");
    }

    /**
     * @dev Ensures we can toggle multiple hats independently.
     */
    function testMultipleHatsToggling() public {
        // Admin toggles hat A on, hat B off
        vm.startPrank(admin);
        toggleModule.setHatStatus(HAT_ID_A, true);
        toggleModule.setHatStatus(HAT_ID_B, false);
        vm.stopPrank();

        // Check each
        uint256 statusA = toggleModule.getHatStatus(HAT_ID_A);
        uint256 statusB = toggleModule.getHatStatus(HAT_ID_B);
        assertEq(statusA, 1, "Hat A should be active");
        assertEq(statusB, 0, "Hat B should be inactive");
    }

    /**
     * @dev Tests that only the admin can transfer admin rights and that
     *      transferring to the zero address reverts.
     */
    function testTransferAdminPermissions() public {
        // 1) nonAdmin tries to transfer => revert
        vm.prank(nonAdmin);
        vm.expectRevert("Not toggle admin");
        toggleModule.transferAdmin(nonAdmin);

        // 2) admin -> zero address => revert
        vm.startPrank(admin);
        vm.expectRevert("Zero address");
        toggleModule.transferAdmin(address(0));

        // 3) admin -> nonAdmin => success
        toggleModule.transferAdmin(nonAdmin);
        vm.stopPrank();
        assertEq(toggleModule.admin(), nonAdmin, "Admin should be transferred to nonAdmin");
    }

    /**
     * @dev Demonstrates that after admin rights are transferred,
     *      the new admin can set hat status, while the old admin cannot.
     */
    function testNewAdminCanSetHatStatus() public {
        // Transfer admin to nonAdmin
        vm.startPrank(admin);
        toggleModule.transferAdmin(nonAdmin);
        vm.stopPrank();

        // new admin can set hat status
        vm.prank(nonAdmin);
        toggleModule.setHatStatus(HAT_ID_A, true);
        uint256 statusA = toggleModule.getHatStatus(HAT_ID_A);
        assertEq(statusA, 1, "New admin should be able to set hat status");

        // old admin tries => revert
        vm.prank(admin);
        vm.expectRevert("Not toggle admin");
        toggleModule.setHatStatus(HAT_ID_B, true);
    }
}
