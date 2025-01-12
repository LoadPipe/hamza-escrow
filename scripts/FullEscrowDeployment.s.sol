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

contract FullEscrowDeployment is Script {
  address internal adminAddress   = address(0x10);     // The admin address
  address internal vaultAddress   = address(0x11);     // The vault that will receive fees
  bool    internal autoRelease    = false;             // Whether PaymentEscrow starts with autoRelease

  function run() external {
    vm.startBroadcast();

    // 1. Deploy the Hats base contract
    Hats hats = new Hats("HamzaHats", "https://example.com/metadata/");

    // 2. Deploy Eligibility & Toggle Modules 
    // pass admin address to each module’s constructor
    EligibilityModule eligibilityModule = new EligibilityModule(adminAddress);
    ToggleModule toggleModule           = new ToggleModule(adminAddress);

    // 3. Mint the Top Hat to admin 
    uint256 adminHatId = hats.mintTopHat(
      adminAddress, 
      "Hamza Admin", 
      "https://example.com/hats/top-hat.json"
    );
    console.log("Top hat ID (adminHatId):", adminHatId);

    // 4. Create child hats
    vm.stopBroadcast();
    vm.startBroadcast(adminAddress);

    uint256 arbiterHatId = hats.createHat(
      adminHatId,
      "Arbiter Hat",
      2,                      // maxSupply
      address(eligibilityModule),
      address(toggleModule),
      true,                   // mutable
      "https://example.com/hats/arbiter-hat.png"
    );

    uint256 daoHatId = hats.createHat(
      adminHatId,
      "DAO Hat",
      1, 
      address(eligibilityModule),
      address(toggleModule),
      true, 
      "https://example.com/hats/dao-hat.png"
    );

    uint256 systemHatId = hats.createHat(
      adminHatId,
      "System Hat",
      1, 
      address(eligibilityModule),
      address(toggleModule),
      true, 
      "https://example.com/hats/system-hat.png"
    );

    uint256 pauserHatId = hats.createHat(
      adminHatId,
      "Pauser Hat",
      1, 
      address(eligibilityModule),
      address(toggleModule),
      true, 
      "https://example.com/hats/pauser-hat.png"
    );

    console.log("Arbiter Hat ID:", arbiterHatId);
    console.log("DAO Hat ID:", daoHatId);
    console.log("System Hat ID:", systemHatId);
    console.log("Pauser Hat ID:", pauserHatId);

    // 5. Deploy HatsSecurityContext & set role hats
    HatsSecurityContext securityContext = new HatsSecurityContext(
      address(hats),
      adminHatId
    );

    // Map each role to the correct hat
    securityContext.setRoleHat(Roles.ARBITER_ROLE, arbiterHatId);
    securityContext.setRoleHat(Roles.DAO_ROLE,     daoHatId);
    securityContext.setRoleHat(Roles.SYSTEM_ROLE,  systemHatId);
    securityContext.setRoleHat(Roles.PAUSER_ROLE,  pauserHatId);

    //--------------------------------------//
    // 6. Deploy SystemSettings             //
    //--------------------------------------//
    // The SystemSettings constructor requires:
    //   IHatsSecurityContext
    //   vaultAddress
    //   initialFeeBps
    SystemSettings systemSettings = new SystemSettings(
      IHatsSecurityContext(address(securityContext)),
      vaultAddress,
      0 // feeBps (0 for now)
    );

    //--------------------------------------//
    // 7. Deploy PaymentEscrow              //
    //--------------------------------------//
    // PaymentEscrow requires:
    //   IHatsSecurityContext
    //   ISystemSettings
    //   autoReleaseFlag
    PaymentEscrow paymentEscrow = new PaymentEscrow(
      IHatsSecurityContext(address(securityContext)),
      ISystemSettings(address(systemSettings)),
      autoRelease
    );

    // ----------------------//
    // 8. Deploy EscrowMulticall
    // ----------------------//
    EscrowMulticall escrowMulticall = new EscrowMulticall();

    vm.stopBroadcast();

    console.log("Hats deployed at:             ", address(hats));
    console.log("EligibilityModule deployed at:", address(eligibilityModule));
    console.log("ToggleModule deployed at:     ", address(toggleModule));
    console.log("HatsSecurityContext deployed: ", address(securityContext));
    console.log("SystemSettings deployed:      ", address(systemSettings));
    console.log("PaymentEscrow deployed:       ", address(paymentEscrow));
  }
}
