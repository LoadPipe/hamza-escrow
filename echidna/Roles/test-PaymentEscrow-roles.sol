// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../../src/PaymentEscrow.sol";
import "../../src/SecurityContext.sol";
import "../../src/SystemSettings.sol";
import "../../src/inc/utils/Hevm.sol";


contract test_RoleInvariants {
    address constant DEPLOYER = address(0x30000);

    // Roles
    address public admin    = address(0xA1);  // Granted ADMIN_ROLE
    address public dao      = address(0xB1);  // Granted DAO_ROLE
    address public system   = address(0xC1);  // Granted SYSTEM_ROLE
    address public arbiter  = address(0xD1);  // Granted ARBITER_ROLE

    // Non-privileged addresses:
    address public rando1   = address(0x9991);
    address public rando2   = address(0x9992);
    address public rando3   = address(0x9993);

    SecurityContext public securityContext;
    SystemSettings  public systemSettings;
    PaymentEscrow   public escrow;

    mapping(address => bool) public setVaultAddressSucceeded;
    mapping(address => bool) public setFeeBpsSucceeded;
    mapping(address => bool) public pauseSucceeded;
    mapping(address => bool) public unpauseSucceeded;
    mapping(address => bool) public setAutoReleaseSucceeded;

    constructor() payable {
        require(msg.value > 0, "Needs initial ETH for escrow tests if needed.");

        // Deploy the SecurityContext and grant roles
        securityContext = new SecurityContext(admin);


        systemSettings = new SystemSettings(
            securityContext,
            admin,  // placeholder for the vaultAddress
            100     // 1% fee
        );

        // Deploy PaymentEscrow
        escrow = new PaymentEscrow(
            securityContext,
            systemSettings,
            false // autoReleaseFlag
        );

        // Grant all needed roles to the respective addresses
        _grantRole(0x00, admin);                       
        _grantRole(escrow.DAO_ROLE(), dao);
        _grantRole(escrow.SYSTEM_ROLE(), system);
        _grantRole(escrow.ARBITER_ROLE(), arbiter);
    }


    function _grantRole(bytes32 role, address to) internal {
        // impersonate the admin or a current role holder to grant a role
        hevm.prank(admin);
        securityContext.grantRole(role, to);
    }

    function trySetVaultAddress(address caller, address newVault) public {
        // Impersonate caller
        hevm.prank(caller);
        try systemSettings.setVaultAddress(newVault) {

            setVaultAddressSucceeded[caller] = true;
        } catch {
            // do nothing
        }
    }

    function trySetFeeBps(address caller, uint256 newFee) public {
        hevm.prank(caller);

        uint256 feeToSet = newFee % 2000; // up to 20% 
        try systemSettings.setFeeBps(feeToSet) {
            setFeeBpsSucceeded[caller] = true;
        } catch {
            // do nothing
        }
    }

    function tryPauseEscrow(address caller) public {
        hevm.prank(caller);
        try escrow.pause() {
            pauseSucceeded[caller] = true;
        } catch {
            // do nothing
        }
    }

    function tryUnpauseEscrow(address caller) public {
        hevm.prank(caller);
        try escrow.unpause() {
            unpauseSucceeded[caller] = true;
        } catch {
            // do nothing
        }
    }

    function trySetAutoReleaseFlag(address caller, bool newFlag) public {
        hevm.prank(caller);
        try escrow.setAutoReleaseFlag(newFlag) {
            setAutoReleaseSucceeded[caller] = true;
        } catch {
            setAutoReleaseSucceeded[caller] = false;
        }
    }

    function echidna_only_dao_can_set_vault_address() public view returns (bool) {

        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            bool success = setVaultAddressSucceeded[a];
            bool hasDao  = securityContext.hasRole(escrow.DAO_ROLE(), a);
            if (success && !hasDao) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_dao_can_set_fee_bps() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            bool success = setFeeBpsSucceeded[a];
            bool hasDao  = securityContext.hasRole(escrow.DAO_ROLE(), a);
            if (success && !hasDao) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_system_can_pause() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            bool success = pauseSucceeded[a];
            bool hasSystem = securityContext.hasRole(escrow.SYSTEM_ROLE(), a);
            if (success && !hasSystem) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_system_can_unpause() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            bool success = unpauseSucceeded[a];
            bool hasSystem = securityContext.hasRole(escrow.SYSTEM_ROLE(), a);
            if (success && !hasSystem) {
                return false;
            }
        }
        return true;
    }

    function echidna_only_system_can_set_auto_release_flag() public view returns (bool) {
        address[6] memory testAddrs = [admin, dao, system, arbiter, rando1, rando2];
        for (uint256 i = 0; i < testAddrs.length; i++) {
            address a = testAddrs[i];
            bool success = setAutoReleaseSucceeded[a];
            bool hasSystem = securityContext.hasRole(escrow.SYSTEM_ROLE(), a);
            if (success && !hasSystem) {
                return false;
            }
        }
        return true;
    }
}
