// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

// Security context & system
import { SecurityContext } from "../src/SecurityContext.sol";
import { ISecurityContext } from "../src/interfaces/ISecurityContext.sol";
import { SystemSettings } from "../src/SystemSettings.sol";
import { PolyEscrow } from "../src/PolyEscrow.sol";

// Roles
import { Roles } from "../src/Roles.sol";

contract DeployPolyEscrow is Script {
  address public securityContext = 0x1234567890123456789012345678901234567890; // Replace with actual SecurityContext address
  address public systemSettings = 0x1234567890123456789012345678901234567890; // Replace with actual SecurityContext address

  address public adminAddress1  = 0x0000000000000000000000000000000000000000;
  uint256 public adminPk = 0x0000000000000000000000000000000000000000000000000000000000000000;
  
  PolyEscrow public polyEscrow;
  

  function run() external {
    console.log("Starting DeployPolyEscrow");
    
    vm.startBroadcast(adminPk);

    //--------------------------------------//
    //  Deploy PolyEscrow                   //
    //--------------------------------------//
    // PolyEscrow requires:
    //   ISecurityContext
    polyEscrow = new PolyEscrow(
      ISecurityContext(securityContext),
      systemSettings
    );

    vm.stopBroadcast();
    
    console.log("PolyEscrow deployed:       ", address(polyEscrow));
  }
}
