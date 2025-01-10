// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@hats-protocol/Hats.sol";
import "../../src/HatsSecurityContext.sol";
import "../../src/PaymentEscrow.sol";
import "../../src/SystemSettings.sol";
import "../../src/IHatsSecurityContext.sol";
import "../../src/ISystemSettings.sol";
import "../../src/PaymentInput.sol";
import "../../src/hats/EligibilityModule.sol";
import "../../src/hats/ToggleModule.sol";
import "@openzeppelin/contracts/utils/Hevm.sol";
// Roles
bytes32 constant DAO_ROLE     = keccak256("DAO_ROLE");
bytes32 constant SYSTEM_ROLE  = keccak256("SYSTEM_ROLE");
bytes32 constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

/**
 * @title test_RoleInvariants (Hats integration + PaymentEscrow + SystemSettings)
 *
 * This contract:
 * 1) Mints exactly ONE top hat to the test contract (adminHatId).
 * 2) Creates child hats for DAO, SYSTEM, ARBITER (under adminHatId).
 * 3) Tests SystemSettings & PaymentEscrow role-based actions via Hats.
 * 4) Deploys & tests the included EligibilityModule + ToggleModule.
 * 5) Contains Echidna invariants ensuring only correct hat wearers
 *    can do certain restricted actions.
 *
 * @author Hudson Headley
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract test_RoleInvariants {
    // Named addresses
    address public admin   = address(0xA1);
    address public dao     = address(0xB1);
    address public system  = address(0xC1);
    address public arbiter = address(0xD1);

    // Non-privileged addresses
    address public rando1  = address(0x9991);
    address public rando2  = address(0x9992);
    address public rando3  = address(0x9993);

    // Hats Protocol & SecurityContext
    Hats public hats;
    HatsSecurityContext public hatsContext;

    // We have exactly one top hat: owned by this contract
    uint256 public adminHatId;

    // Child hats for each role
    uint256 public daoHatId;
    uint256 public systemHatId;
    uint256 public arbiterHatId;

    // Contracts Under Test
    SystemSettings public systemSettings;
    PaymentEscrow public escrow;

    // Modules Under Test
    EligibilityModule public eligibilityModule;
    ToggleModule public toggleModule;

    // Tracking Access Attempts: PaymentEscrow & SystemSettings
    mapping(address => bool) public setVaultAddressSucceeded;
    mapping(address => bool) public setFeeBpsSucceeded;
    mapping(address => bool) public pauseSucceeded;
    mapping(address => bool) public unpauseSucceeded;
    mapping(address => bool) public setAutoReleaseSucceeded;

    // Tracking Access Attempts: Modules
    mapping(address => bool) public setHatRulesSucceeded;
    mapping(address => bool) public setHatStatusSucceeded;

    // Constructor
    /**
     * @dev Mints one top hat to `address(this)` => adminHatId. Creates child hats
     *      for the DAO, SYSTEM, and ARBITER roles. Deploys SystemSettings &
     *      PaymentEscrow with hats-based security. Deploys the modules and sets
     *      test contract as their admin.
     */
    constructor() payable {
        require(msg.value > 0, "Needs initial ETH for escrow tests if needed.");

        // 1) Deploy the main Hats contract
        hats = new Hats("Test Hats", "ipfs://test");

        // 2) Mint ONE top hat to the test contract => adminHatId
        adminHatId = hats.mintTopHat(address(this), "Admin Hat", "ipfs://admin");

        // 3) Deploy modules here (test contract as admin)
        eligibilityModule = new EligibilityModule(address(this));
        toggleModule      = new ToggleModule(address(this));

        eligibilityModule.setHatRules(adminHatId, true, true);
        toggleModule.setHatStatus(adminHatId, true);
        // 4) Create child hats for each role:
        //    (adminHatId, "DAO Hat", etc.)
        daoHatId = hats.createHat(
            adminHatId,
            "DAO Hat",
            1, // max supply
            address(eligibilityModule),
            address(toggleModule),
            true, // mutable
            "ipfs://dao"
        );
        eligibilityModule.setHatRules(daoHatId, true, true);
        toggleModule.setHatStatus(daoHatId, true);

        systemHatId = hats.createHat(
            adminHatId,
            "System Hat",
            1, // max supply
            address(eligibilityModule),
            address(toggleModule),
            true,
            "ipfs://system"
        );
        eligibilityModule.setHatRules(systemHatId, true, true);
        toggleModule.setHatStatus(systemHatId, true);

        arbiterHatId = hats.createHat(
            adminHatId,
            "Arbiter Hat",
            1, // max supply
            address(eligibilityModule),
            address(toggleModule),
            true,
            "ipfs://arbiter"
        );
        eligibilityModule.setHatRules(arbiterHatId, true, true);
        toggleModule.setHatStatus(arbiterHatId, true);  

        // 5) Actually mint those child hats to the respective addresses
        //    (requires that this contract is wearing the adminHatId)
        hats.mintHat(daoHatId, dao);
        hats.mintHat(systemHatId, system);
        hats.mintHat(arbiterHatId, arbiter);

        // 6) Deploy HatsSecurityContext with adminHatId
        hatsContext = new HatsSecurityContext(address(hats), adminHatId);

        // 7) Map role bytes => hat IDs
        hatsContext.setRoleHat(DAO_ROLE,     daoHatId);
        hatsContext.setRoleHat(SYSTEM_ROLE,  systemHatId);
        hatsContext.setRoleHat(ARBITER_ROLE, arbiterHatId);

        // 8) Deploy SystemSettings & PaymentEscrow
        systemSettings = new SystemSettings(
            IHatsSecurityContext(address(hatsContext)),
            /* vaultAddress */ admin,
            /* initialFeeBps */ 100 // 1% fee
        );

        escrow = new PaymentEscrow(
            IHatsSecurityContext(address(hatsContext)),
            ISystemSettings(address(systemSettings)),
            false // autoReleaseFlag
        );
    }

    // PaymentEscrow & SystemSettings Methods
    function trySetVaultAddress(address caller, address newVault) public {
        hevm.prank(caller);
        try systemSettings.setVaultAddress(newVault) {
            setVaultAddressSucceeded[caller] = true;
        } catch {}
    }

    function trySetFeeBps(address caller, uint256 newFee) public {
        hevm.prank(caller);
        uint256 feeToSet = newFee % 2000; // limit to 20%
        try systemSettings.setFeeBps(feeToSet) {
            setFeeBpsSucceeded[caller] = true;
        } catch {}
    }

    function tryPauseEscrow(address caller) public {
        hevm.prank(caller);
        try escrow.pause() {
            pauseSucceeded[caller] = true;
        } catch {}
    }

    function tryUnpauseEscrow(address caller) public {
        hevm.prank(caller);
        try escrow.unpause() {
            unpauseSucceeded[caller] = true;
        } catch {}
    }

    function trySetAutoReleaseFlag(address caller, bool newFlag) public {
        hevm.prank(caller);
        try escrow.setAutoReleaseFlag(newFlag) {
            setAutoReleaseSucceeded[caller] = true;
        } catch {
            setAutoReleaseSucceeded[caller] = false;
        }
    }

    // Modules Methods
    function trySetHatRules(address caller, uint256 hatId, bool _eligible, bool _standing) public {
        hevm.prank(caller);
        try eligibilityModule.setHatRules(hatId, _eligible, _standing) {
            setHatRulesSucceeded[caller] = true;
        } catch {}
    }

    function trySetHatStatus(address caller, uint256 hatId, bool _active) public {
        hevm.prank(caller);
        try toggleModule.setHatStatus(hatId, _active) {
            setHatStatusSucceeded[caller] = true;
        } catch {}
    }

    // Invariants for PaymentEscrow & SystemSettings
    function echidna_only_dao_can_set_vault_address() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (setVaultAddressSucceeded[testAddrs[i]] && !hats.isWearerOfHat(testAddrs[i], daoHatId)) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_dao_can_set_fee_bps() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (setFeeBpsSucceeded[testAddrs[i]] && !hats.isWearerOfHat(testAddrs[i], daoHatId)) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_system_can_pause() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (pauseSucceeded[testAddrs[i]] && !hats.isWearerOfHat(testAddrs[i], systemHatId)) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_system_can_unpause() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (unpauseSucceeded[testAddrs[i]] && !hats.isWearerOfHat(testAddrs[i], systemHatId)) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_system_can_set_auto_release_flag() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (setAutoReleaseSucceeded[testAddrs[i]] && !hats.isWearerOfHat(testAddrs[i], systemHatId)) {
                return false;
            }
        }
        return true;
    }

    // Invariants for Modules
    // Only the module admin can set HatRules in EligibilityModule
    function echidna_only_module_admin_can_setHatRules() public view returns (bool) {
        // If someone else succeeded, return false
        address[5] memory testAddrs = [admin, dao, system, arbiter, rando1];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (setHatRulesSucceeded[testAddrs[i]]) {
                return false;
            }
        }
        return true;
    }

    // Only the module admin can set HatStatus in ToggleModule
    function echidna_only_module_admin_can_setHatStatus() public view returns (bool) {
        address[5] memory testAddrs = [admin, dao, system, arbiter, rando1];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            if (setHatStatusSucceeded[testAddrs[i]]) {
                return false;
            }
        }
        return true;
    }
}