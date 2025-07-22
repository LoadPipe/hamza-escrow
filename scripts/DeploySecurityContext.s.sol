// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

// Security context & system
import { SecurityContext } from "../src/SecurityContext.sol";
import { ISecurityContext } from "../src/interfaces/ISecurityContext.sol";

// Roles
import { Roles } from "../src/Roles.sol";

contract DeploySecurityContext is Script {
  address public adminAddress1  = 0x0000000000000000000000000000000000000000;
  uint256 public adminPk = 0x0000000000000000000000000000000000000000000000000000000000000000;
  
  SecurityContext public securityContext;
  
  function run() external {
    console.log("Starting DeploySecurityContext");
    
    vm.startBroadcast(adminPk);

    //--------------------------------------//
    //  Deploy SecurityContext              //
    //--------------------------------------//
    // SecurityContext requires:
    securityContext = new SecurityContext(adminAddress1);

    vm.stopBroadcast();
    
    console.log("SecurityContext deployed:  ", address(securityContext));
  }
}
