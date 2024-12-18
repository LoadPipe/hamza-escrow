// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SecurityContext.sol";
import "../src/HasSecurityContext.sol";
import "../src/ISecurityContext.sol";

bytes32 constant ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
bytes32 constant ARBITER_ROLE = 0xbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae;
bytes32 constant DAO_ROLE = 0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603;

error AccessControlBadConfirmation();

contract SecurityContextTest is Test {
    SecurityContext internal securityContext;
    address internal admin;
    address internal nonAdmin1;
    address internal nonAdmin2;

    function setUp() public {
        admin = address(1);
        nonAdmin1 = address(2);
        nonAdmin2 = address(3);

        vm.deal(admin, 100 ether);
        vm.deal(nonAdmin1, 100 ether);
        vm.deal(nonAdmin2, 100 ether);

        vm.startPrank(admin);
        securityContext = new SecurityContext(admin, address(0), bytes32(0));
        vm.stopPrank();
    }

    function grantRole(bytes32 role, address to, address caller) internal {
        vm.prank(caller);
        securityContext.grantRole(role, to);
    }

    function revokeRole(bytes32 role, address from, address caller) internal {
        vm.prank(caller);
        securityContext.revokeRole(role, from);
    }

    // Deployment
    function testDeploymentShouldSetRightOwner() public {
        assertTrue(securityContext.hasRole(ADMIN_ROLE, admin));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin1));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin2));
    }

    // Transfer Adminship
    function testCanGrantAdminToSelf() public {
        vm.prank(admin);
        securityContext.grantRole(ADMIN_ROLE, admin);

        assertTrue(securityContext.hasRole(ADMIN_ROLE, admin));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin1));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin2));
    }

    function testCanTransferAdminToAnother() public {
        vm.prank(admin);
        securityContext.grantRole(ADMIN_ROLE, nonAdmin1);

        // now two admins: admin and nonAdmin1
        assertTrue(securityContext.hasRole(ADMIN_ROLE, admin));
        assertTrue(securityContext.hasRole(ADMIN_ROLE, nonAdmin1));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin2));

        vm.prank(nonAdmin1);
        securityContext.revokeRole(ADMIN_ROLE, admin);

        // now only nonAdmin1 is admin
        assertFalse(securityContext.hasRole(ADMIN_ROLE, admin));
        assertTrue(securityContext.hasRole(ADMIN_ROLE, nonAdmin1));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin2));
    }

    function testCanPassAdminshipAlong() public {
        vm.prank(admin);
        securityContext.grantRole(ADMIN_ROLE, nonAdmin1);

        vm.prank(nonAdmin1);
        securityContext.revokeRole(ADMIN_ROLE, admin);

        vm.prank(nonAdmin1);
        securityContext.grantRole(ADMIN_ROLE, nonAdmin2);

        vm.prank(nonAdmin2);
        securityContext.revokeRole(ADMIN_ROLE, nonAdmin1);

        // passed from admin -> nonAdmin1 -> nonAdmin2
        assertFalse(securityContext.hasRole(ADMIN_ROLE, admin));
        assertFalse(securityContext.hasRole(ADMIN_ROLE, nonAdmin1));
        assertTrue(securityContext.hasRole(ADMIN_ROLE, nonAdmin2));
    }

    // Restrictions
    function setUpRestrictions() public {
        grantRole(ARBITER_ROLE, admin, admin);
        grantRole(DAO_ROLE, admin, admin);
    }

    // Tests here were skipped. They seemed to refrence a master switch that was not implemented (or not yet)

    function testAdminCannotRenounceAdminRole() public {
        setUpRestrictions();

        // admin has admin role
        assertTrue(securityContext.hasRole(ADMIN_ROLE, admin));

        // try to renounce
        vm.prank(admin);
        securityContext.renounceRole(ADMIN_ROLE, admin);

        // role not renounced
        assertTrue(securityContext.hasRole(ADMIN_ROLE, admin));
    }

    function testAdminCanRenounceNonAdminRole() public {
        setUpRestrictions();

        // admin has ARBITER and DAO roles
        assertTrue(securityContext.hasRole(ARBITER_ROLE, admin));
        assertTrue(securityContext.hasRole(DAO_ROLE, admin));

        // renounce them
        vm.prank(admin);
        securityContext.renounceRole(ARBITER_ROLE, admin);

        vm.prank(admin);
        securityContext.renounceRole(DAO_ROLE, admin);

        // now admin lost these roles
        assertFalse(securityContext.hasRole(ARBITER_ROLE, admin));
        assertFalse(securityContext.hasRole(DAO_ROLE, admin));
    }

    function testAdminCanRevokeOwnNonAdminRole() public {
        setUpRestrictions();
        // admin has ARBITER and DAO
        assertTrue(securityContext.hasRole(ARBITER_ROLE, admin));
        assertTrue(securityContext.hasRole(DAO_ROLE, admin));

        vm.prank(admin);
        securityContext.revokeRole(ARBITER_ROLE, admin);

        vm.prank(admin);
        securityContext.revokeRole(DAO_ROLE, admin);

        assertFalse(securityContext.hasRole(ARBITER_ROLE, admin));
        assertFalse(securityContext.hasRole(DAO_ROLE, admin));
    }

    function testAdminCannotRevokeOwnAdminRole() public {
        setUpRestrictions();

        // admin tries to revoke admin role from itself
        vm.prank(admin);
        securityContext.revokeRole(ADMIN_ROLE, admin);

        // still admin
        assertTrue(securityContext.hasRole(ADMIN_ROLE, admin));
    }

    function testCannotRenounceAnotherAddressRole() public {
        vm.prank(admin);
        securityContext.grantRole(ARBITER_ROLE, nonAdmin1);

        vm.prank(admin);
        securityContext.grantRole(ARBITER_ROLE, nonAdmin2);

        // Assert that both have the ARBITER_ROLE
        assertTrue(securityContext.hasRole(ARBITER_ROLE, nonAdmin1));
        assertTrue(securityContext.hasRole(ARBITER_ROLE, nonAdmin2));

        // Attempt to renounce others role which should revert with access control error
        vm.prank(nonAdmin1);
        vm.expectRevert(AccessControlBadConfirmation.selector); 
        securityContext.renounceRole(ARBITER_ROLE, nonAdmin2);

        vm.prank(nonAdmin2);
        vm.expectRevert(AccessControlBadConfirmation.selector); 
        securityContext.renounceRole(ARBITER_ROLE, nonAdmin1);

        // Ensure they can renounce their own roles
        vm.prank(nonAdmin1);
        securityContext.renounceRole(ARBITER_ROLE, nonAdmin1);

        vm.prank(nonAdmin2);
        securityContext.renounceRole(ARBITER_ROLE, nonAdmin2);

        // Confirm roles are removed after self renounce
        assertFalse(securityContext.hasRole(ARBITER_ROLE, nonAdmin1));
        assertFalse(securityContext.hasRole(ARBITER_ROLE, nonAdmin2));
    }


}
