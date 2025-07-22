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

contract FullEscrowDeployment is Script {
  address public adminAddress1  = 0x0000000000000000000000000000000000000000;
  uint256 public adminPk = 0x0000000000000000000000000000000000000000000000000000000000000000;

  SecurityContext public securityContext;
  PolyEscrow public polyEscrow;
  SystemSettings public systemSettings;
  

  function run() external {
    console.log("Starting FullEscrowDeployment");
    
    vm.startBroadcast(adminPk);


    //--------------------------------------//
    //  Deploy SecurityContext              //
    //--------------------------------------//
    // SecurityContext requires:
    securityContext = new SecurityContext(adminAddress1);


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
    
    console.log("SecurityContext deployed:  ", address(securityContext));
    console.log("SystemSettings deployed:   ", address(systemSettings));
    console.log("PolyEscrow deployed:       ", address(polyEscrow));
  }
}
