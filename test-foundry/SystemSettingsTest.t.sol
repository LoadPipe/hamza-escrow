// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../lib/hats-protocol/src/Hats.sol";
import "../src/HatsSecurityContext.sol";
import "../src/SystemSettings.sol";
import "../src/IHatsSecurityContext.sol";
import "../src/hats/EligibilityModule.sol";
import "../src/hats/ToggleModule.sol";

contract SystemSettingsTest is Test {
    Hats internal hats;
    HatsSecurityContext internal securityContext;
    SystemSettings internal systemSettings;
    EligibilityModule internal eligibilityModule;
    ToggleModule internal toggleModule;

    address internal admin;
    address internal nonOwner;
    address internal vaultAddress;
    address internal dao;

    // Hat IDs
    uint256 internal adminHatId;
    uint256 internal daoHatId;

    bytes32 internal constant DAO_ROLE = keccak256("DAO_ROLE");
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        // Setup addresses
        admin = address(1);
        nonOwner = address(2);
        vaultAddress = address(3);
        dao = address(4);

        // Deploy modules
        eligibilityModule = new EligibilityModule(admin);
        toggleModule = new ToggleModule(admin);

        // Deploy Hats Protocol
        hats = new Hats("Test Hats", "ipfs://");
        
        // Create admin hat
        adminHatId = hats.mintTopHat(admin, "Admin Hat", "ipfs://admin.hat");
        
        vm.startPrank(admin);
        
        // Create DAO hat with real modules
        daoHatId = hats.createHat(
            adminHatId,
            "DAO Hat",
            1,
            address(eligibilityModule),
            address(toggleModule),
            true,
            "ipfs://dao.hat"
        );

        // Set eligibility and standing for DAO hat
        eligibilityModule.setHatRules(daoHatId, true, true);

        // Set DAO hat as active
        toggleModule.setHatStatus(daoHatId, true);

        // Deploy HatsSecurityContext
        securityContext = new HatsSecurityContext(address(hats), adminHatId);
        
        // Map DAO role to hat
        securityContext.setRoleHat(DAO_ROLE, daoHatId);

        // Mint hat to DAO address
        hats.mintHat(daoHatId, dao);

        // Deploy SystemSettings
        systemSettings = new SystemSettings(IHatsSecurityContext(address(securityContext)), vaultAddress, 100);
        vm.stopPrank();
    }

    // Deployment tests
    function testDeploymentShouldSetCorrectValues() public {
        assertEq(systemSettings.feeBps(), 100);
        assertEq(systemSettings.vaultAddress(), vaultAddress);
        assertTrue(hats.isWearerOfHat(dao, daoHatId), "DAO should wear DAO hat");
        assertEq(securityContext.roleToHatId(DAO_ROLE), daoHatId, "DAO role should map to correct hat");
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
        vm.startPrank(admin);
        vm.expectRevert("InvalidVaultAddress");
        new SystemSettings(IHatsSecurityContext(address(securityContext)), address(0), 100);
        vm.stopPrank();
    }

    function testCannotSetZeroAddressSecurityContext() public {
        // Setting a valid security context again is allowed
        vm.prank(admin);
        systemSettings.setSecurityContext(IHatsSecurityContext(address(securityContext)));

        // Setting zero address should revert
        vm.prank(admin);
        vm.expectRevert();
        systemSettings.setSecurityContext(IHatsSecurityContext(address(0)));
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
