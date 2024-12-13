// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SecurityContext.sol";
import "../src/SystemSettings.sol";
import "../src/ISecurityContext.sol";

contract SystemSettingsTest is Test {
    SecurityContext internal securityContext;
    SystemSettings internal systemSettings;

    address internal admin;
    address internal nonOwner;
    address internal vaultAddress;
    address internal dao;

    bytes32 internal constant DAO_ROLE =
        0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603;

    function setUp() public {
        // Setup addresses
        admin = address(1);
        nonOwner = address(2);
        vaultAddress = address(3);
        dao = address(4);

        // Deploy SecurityContext with admin
        vm.startPrank(admin);
        securityContext = new SecurityContext(admin);
        vm.stopPrank();

        // Grant dao role
        vm.prank(admin);
        securityContext.grantRole(DAO_ROLE, dao);

        // Deploy SystemSettings
        vm.prank(admin);
        systemSettings = new SystemSettings(ISecurityContext(address(securityContext)), vaultAddress, 100);
    }

    // Deployment tests
    function testDeploymentShouldSetCorrectValues() public {
        assertEq(systemSettings.feeBps(), 100);
        assertEq(systemSettings.vaultAddress(), vaultAddress);
    }

    // Security tests
    function testDaoRoleCanSetProperties() public {
        address vaultAddress2 = admin;

        // dao sets values
        vm.prank(dao);
        systemSettings.setFeeBps(204);

        vm.prank(dao);
        systemSettings.setVaultAddress(vaultAddress2);

        assertEq(systemSettings.feeBps(), 204);
        assertEq(systemSettings.vaultAddress(), vaultAddress2);
    }

    function testNonDaoCannotSetProperties() public {
        address vaultAddress2 = admin;

        // Non-DAO cannot set vault or fee
        vm.startPrank(admin);
        vm.expectRevert(); 
        systemSettings.setFeeBps(101);

        vm.expectRevert(); 
        systemSettings.setVaultAddress(vaultAddress2);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        vm.expectRevert(); 
        systemSettings.setFeeBps(101);

        vm.expectRevert(); 
        systemSettings.setVaultAddress(vaultAddress2);
        vm.stopPrank();
    }

    function testCanSetZeroFeeBps() public {
        vm.prank(dao);
        systemSettings.setFeeBps(0);
        assertEq(systemSettings.feeBps(), 0);
    }

    function testCannotSetZeroAddressVault() public {
        vm.prank(dao);
        vm.expectRevert(); // must revert if setting vault to zero address
        systemSettings.setVaultAddress(address(0));
    }

    function testCannotSetZeroAddressVaultInConstructor() public {
        vm.expectRevert("InvalidVaultAddress");
        new SystemSettings(ISecurityContext(address(securityContext)), address(0), 100);
    }

    function testCannotSetZeroAddressSecurityContext() public {
        // Setting a valid security context again is allowed
        vm.prank(admin);
        systemSettings.setSecurityContext(ISecurityContext(address(securityContext)));

        // Setting zero address should revert
        vm.prank(admin);
        vm.expectRevert();
        systemSettings.setSecurityContext(ISecurityContext(address(0)));
    }

    // event tests

    //events 
    event VaultAddressChanged (
        address newAddress,
        address changedBy
    );

    event FeeBpsChanged (
        uint256 newValue,
        address changedBy
    );

    function testSetVaultAddressEmitsEvent() public {
        address newVaultAddress = address(5);

        // set new value
        vm.prank(dao);
        vm.expectEmit(true, true, true, true);
        emit VaultAddressChanged(newVaultAddress, dao);
        systemSettings.setVaultAddress(newVaultAddress);

        // check new value
        assertEq(systemSettings.vaultAddress(), newVaultAddress);
    }

    function testSetFeeBpsEmitsEvent() public {
        uint256 newFeeBps = 150;

       // set new value
        vm.prank(dao);
        vm.expectEmit(true, true, true, true);
        emit FeeBpsChanged(newFeeBps, dao);
        systemSettings.setFeeBps(newFeeBps);

        // check new value
        assertEq(systemSettings.feeBps(), newFeeBps);
    }

    function testSetVaultAddressDoesNotEmitIfUnchanged() public {
        address unchangedVaultAddress = systemSettings.vaultAddress();

        // set vault same as current
        vm.prank(dao);
        vm.recordLogs(); 
        systemSettings.setVaultAddress(unchangedVaultAddress);

        // assert no events
        Vm.Log[] memory logs = vm.getRecordedLogs(); 
        assertEq(logs.length, 0, "No event should have been emitted");
    }

    function testSetFeeBpsDoesNotEmitIfUnchanged() public {
        uint256 unchangedFeeBps = systemSettings.feeBps();

        // set fee same as current
        vm.prank(dao);
        vm.recordLogs(); 
        systemSettings.setFeeBps(unchangedFeeBps);

        // assert no events
        Vm.Log[] memory logs = vm.getRecordedLogs(); 
        assertEq(logs.length, 0, "No event should have been emitted");
    }

}
