// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../../src/PaymentEscrow.sol";
import "../../src/SecurityContext.sol";
import "../../src/SystemSettings.sol";
import "../../src/inc/utils/Hevm.sol";

/**
 * @title test_RoleInvariants
 *
 * Tests role-based access control in the context of PaymentEscrow and SystemSettings contracts.
 * Ensures only privileged roles can perform specific actions
 *
 * @author Hudson Headley
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract test_RoleInvariants {
    address constant DEPLOYER = address(0x30000); // Deployer account

    // Predefined roles with their respective addresses
    address public admin = address(0xA1); // Granted ADMIN_ROLE
    address public dao = address(0xB1); // Granted DAO_ROLE
    address public system = address(0xC1); // Granted SYSTEM_ROLE
    address public arbiter = address(0xD1); // Granted ARBITER_ROLE

    // Non-privileged addresses
    address public rando1 = address(0x9991);
    address public rando2 = address(0x9992);
    address public rando3 = address(0x9993);

    // Contracts under test
    SecurityContext public securityContext; // Manages roles and access control
    SystemSettings public systemSettings; // Manages global system settings
    PaymentEscrow public escrow; // Handles payment-related actions

    // Tracks whether specific operations succeeded for different callers
    mapping(address => bool) public setVaultAddressSucceeded;
    mapping(address => bool) public setFeeBpsSucceeded;
    mapping(address => bool) public pauseSucceeded;
    mapping(address => bool) public unpauseSucceeded;
    mapping(address => bool) public setAutoReleaseSucceeded;

    /**
     * @dev Constructor initializes the test environment by deploying contracts and assigning roles.
     * Requires an initial balance for escrow-related operations.
     */
    constructor() payable {
        require(msg.value > 0, "Needs initial ETH for escrow tests if needed.");

        // Deploy SecurityContext and grant roles

        securityContext = new SecurityContext(msg.sender);

        // Deploy SystemSettings with initial vault and fee settings
        systemSettings = new SystemSettings(
            IHatsSecurityContext(address(securityContext)),
            admin, // Placeholder vault address
            100 // 1% fee in basis points
        );

        // Deploy PaymentEscrow with the system settings
        escrow = new PaymentEscrow(
            IHatsSecurityContext(address(securityContext)),
            ISystemSettings(address(systemSettings)),
            false // autoReleaseFlag disabled
        );

        // Grant required roles to respective addresses
        _grantRole(0x00, admin); // Grant default admin role
        _grantRole(keccak256("DAO_ROLE"), dao);
        _grantRole(keccak256("SYSTEM_ROLE"), system);
        _grantRole(keccak256("ARBITER_ROLE"), arbiter);
    }

    /**
     * Grants a specific role to an address.
     *
     * @param role The role to be granted.
     * @param to The address to grant the role to.
     */
    function _grantRole(bytes32 role, address to) internal {
        hevm.prank(admin); // Impersonate the admin for the role grant
        securityContext.grantRole(role, to);
    }

    /**
     * Attempts to set the vault address by impersonating the caller.
     *
     * @param caller The address attempting the action.
     * @param newVault The new vault address to set.
     */
    function trySetVaultAddress(address caller, address newVault) public {
        hevm.prank(caller); // Impersonate caller
        try systemSettings.setVaultAddress(newVault) {
            setVaultAddressSucceeded[caller] = true;
        } catch {
            // Do nothing on failure
        }
    }

    /**
     * Attempts to set the fee basis points by impersonating the caller.
     *
     * @param caller The address attempting the action.
     * @param newFee The new fee in basis points.
     */
    function trySetFeeBps(address caller, uint256 newFee) public {
        hevm.prank(caller); // Impersonate caller
        uint256 feeToSet = newFee % 2000; // Limit to 20%
        try systemSettings.setFeeBps(feeToSet) {
            setFeeBpsSucceeded[caller] = true;
        } catch {
            // Do nothing on failure
        }
    }

    /**
     * Attempts to pause the escrow by impersonating the caller.
     *
     * @param caller The address attempting the action.
     */
    function tryPauseEscrow(address caller) public {
        hevm.prank(caller); // Impersonate caller
        try escrow.pause() {
            pauseSucceeded[caller] = true;
        } catch {
            // Do nothing on failure
        }
    }

    /**
     * Attempts to unpause the escrow by impersonating the caller.
     *
     * @param caller The address attempting the action.
     */
    function tryUnpauseEscrow(address caller) public {
        hevm.prank(caller); // Impersonate caller
        try escrow.unpause() {
            unpauseSucceeded[caller] = true;
        } catch {
            // Do nothing on failure
        }
    }

    /**
     * Attempts to set the auto-release flag by impersonating the caller.
     *
     * @param caller The address attempting the action.
     * @param newFlag The new value for the auto-release flag.
     */
    function trySetAutoReleaseFlag(address caller, bool newFlag) public {
        hevm.prank(caller); // Impersonate caller
        try escrow.setAutoReleaseFlag(newFlag) {
            setAutoReleaseSucceeded[caller] = true;
        } catch {
            setAutoReleaseSucceeded[caller] = false;
        }
    }

    /**
     * Invariant: Only the DAO role can set the vault address.
     */
    function echidna_only_dao_can_set_vault_address() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            if (setVaultAddressSucceeded[a] && !securityContext.hasRole(keccak256("DAO_ROLE"), a)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Only the DAO role can set the fee basis points.
     */
    function echidna_only_dao_can_set_fee_bps() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            if (setFeeBpsSucceeded[a] && !securityContext.hasRole(keccak256("DAO_ROLE"), a)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Only the system role can pause the escrow.
     */
    function echidna_only_system_can_pause() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            if (pauseSucceeded[a] && !securityContext.hasRole(keccak256("SYSTEM_ROLE"), a)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Only the system role can unpause the escrow.
     */
    function echidna_only_system_can_unpause() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            if (unpauseSucceeded[a] && !securityContext.hasRole(keccak256("SYSTEM_ROLE"), a)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Invariant: Only the system role can set the auto-release flag.
     */
    function echidna_only_system_can_set_auto_release_flag() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            if (setAutoReleaseSucceeded[a] && !securityContext.hasRole(keccak256("SYSTEM_ROLE"), a)) {
                return false;
            }
        }
        return true;
    }
}
