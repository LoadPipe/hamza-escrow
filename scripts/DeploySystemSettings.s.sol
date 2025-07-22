// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

// Security context & system
import { SecurityContext } from "../src/SecurityContext.sol";
import { ISecurityContext } from "../src/interfaces/ISecurityContext.sol";
import { SystemSettings } from "../src/SystemSettings.sol";

// Roles
import { Roles } from "../src/Roles.sol";

contract DeploySystemSettings is Script {
  address public securityContext = 0x1234567890123456789012345678901234567890; // Replace with actual SecurityContext address
  
  address public adminAddress1  = 0x0000000000000000000000000000000000000000;
  uint256 public adminPk = 0x0000000000000000000000000000000000000000000000000000000000000000;

  SystemSettings public systemSettings;
  
  function run() external {
    console.log("Starting DeploySystemSettings");
    
    vm.startBroadcast(adminPk);

    //--------------------------------------//
    // Deploy SystemSettings             //
    //--------------------------------------//
    // The SystemSettings constructor requires:
    //   ISecurityContext
    //   vaultAddress
    //   initialFeeBps
    systemSettings = new SystemSettings(
      ISecurityContext(securityContext),
      address(0x01), //CHANGE FOR VAULT
      0 // feeBps (0 for now)
    );

    vm.stopBroadcast();
    
    console.log("SystemSettings deployed:  ", address(systemSettings));
  }
}
