// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

// Hats Protocol
import { Hats } from "@hats-protocol/Hats.sol";

// Hats modules
import { EligibilityModule } from "../src/hats/EligibilityModule.sol";
import { ToggleModule } from "../src/hats/ToggleModule.sol";

// Security context & system
import { HatsSecurityContext } from "../src/HatsSecurityContext.sol";
import { IHatsSecurityContext } from "../src/IHatsSecurityContext.sol";
import { SystemSettings } from "../src/SystemSettings.sol";
import { ISystemSettings } from "../src/ISystemSettings.sol";
import { PaymentEscrow } from "../src/PaymentEscrow.sol";
import {EscrowMulticall} from "../src/EscrowMulticall.sol";

// Roles
import { Roles } from "../src/Roles.sol";

import "./HatsDeployment.s.sol";

contract FullEscrowDeployment is Script {
  address public adminAddress1   = 0x1310cEdD03Cc8F6aE50F2Fb93848070FACB042b8;
  address public adminAddress2 = 0x1542612fee591eD35C05A3E980bAB325265c06a3;
  bool    internal autoRelease    = true;             // Whether PaymentEscrow starts with autoRelease

  Hats public hats;
  EligibilityModule public eligibilityModule;
  ToggleModule public toggleModule;
  HatsSecurityContext public securityContext;
  SystemSettings public systemSettings;
  PaymentEscrow public paymentEscrow;
  EscrowMulticall public escrowMulticall;

  uint256 public adminHatId;
  uint256 public arbiterHatId;
  uint256 public daoHatId;
  uint256 public topHatId;
  

  function run() external {
    console.log("Starting FullEscrowDeployment");

    HatsDeployment hatsDeployment = new HatsDeployment();
    (address safeAddr, address hatsSecurityContextAddr) = hatsDeployment.run();
    
    vm.startBroadcast(adminAddress1);
    //--------------------------------------//
    // 8. Deploy SystemSettings             //
    //--------------------------------------//
    // The SystemSettings constructor requires:
    //   IHatsSecurityContext
    //   vaultAddress
    //   initialFeeBps
    systemSettings = new SystemSettings(
      IHatsSecurityContext(hatsSecurityContextAddr),
      safeAddr, //CHANGE FOR VAULT
      0 // feeBps (0 for now)
    );

    //--------------------------------------//
    // 9. Deploy PaymentEscrow              //
    //--------------------------------------//
    // PaymentEscrow requires:
    //   IHatsSecurityContext
    //   ISystemSettings
    //   autoReleaseFlag
    paymentEscrow = new PaymentEscrow(
      IHatsSecurityContext(hatsSecurityContextAddr),
      ISystemSettings(address(systemSettings)),
      autoRelease
    );

    // ----------------------//
    // 10. Deploy EscrowMulticall
    // ----------------------//
    escrowMulticall = new EscrowMulticall();

    vm.stopBroadcast();
    
    console.log("SystemSettings deployed:      ", address(systemSettings));
    console.log("PaymentEscrow deployed:       ", address(paymentEscrow));
    console.log("EscrowMulticall deployed:     ", address(escrowMulticall));
  }
}
