// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

import { SafeTransactionHelper } from "./utils/SafeTransactionHelper.s.sol";

// Minimal interface to read the Gnosis Safe's nonce.
interface IGnosisSafe {
    function nonce() external view returns (uint256);
}

// Hats Protocol
import { Hats } from "@hats-protocol/Hats.sol";
import { EligibilityModule } from "../src/hats/EligibilityModule.sol";
import { ToggleModule } from "../src/hats/ToggleModule.sol";
import { HatsSecurityContext } from "../src/security/HatsSecurityContext.sol";
import { Roles } from "../src/security/Roles.sol";

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

/**
 * @title HatsDeployment
 * @notice Script to deploy the Hats protocol contracts and safe
 */
contract HatsDeployment is Script {

    // Gnosis Safe singleton & factory on Sepolia
    address constant SAFE_SINGLETON = 0x69f4D1788e39c87893C980c06EdF4b7f686e2938;
    address constant SAFE_FACTORY  = 0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC;

    // The second owner (besides adminAddress1)
    address public adminAddress2 = 0x1542612fee591eD35C05A3E980bAB325265c06a3; // hudson's address: 0x1310cEdD03Cc8F6aE50F2Fb93848070FACB042b8

    // The newly deployed Safe
    address public deployedSafe;

    // Hats references
    Hats public hats;
    EligibilityModule public eligibilityModule;
    ToggleModule public toggleModule;
    HatsSecurityContext public securityContext;

    uint256 public adminHatId;
    uint256 public arbiterHatId;
    uint256 public daoHatId;
    uint256 public topHatId;
    uint256 public systemHatId;
    uint256 public pauserHatId;

    // Deployer's private key and derived addresses
    uint256 internal deployerPk;
    address internal adminAddress1;

    function execTransaction(address to, address target, uint256 value, bytes memory data) internal {
        SafeTransactionHelper.execTransaction(to, target, value, data, adminAddress1);
    }

    /**
     * @notice Runs the deployment. Returns the newly deployed safe address
     */
    function run() external returns (address, address) {
        // 1) load deployer private key
        deployerPk = vm.envUint("PRIVATE_KEY");
        adminAddress1 = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        console.log("Deployer EOA (adminAddress1):", adminAddress1);
        console.log("Starting Hats deployment with v=1 (approved hash) signatures...");

        // 2) Use existing Hats or deploy a new instance
        hats = Hats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
        // hats = new Hats("Hats Protocol v1", "ipfs://...");

        // 3) Deploy a new Gnosis Safe (1-of-2 owners)
        GnosisSafeProxyFactory factory = GnosisSafeProxyFactory(SAFE_FACTORY);
        address[] memory owners = new address[](2);
        owners[0] = adminAddress1;
        owners[1] = adminAddress2;

        bytes memory setupData = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            1,        // threshold = 1
            address(0),
            "",
            address(0),
            address(0),
            0,
            address(0)
        );

        address safeAddr = address(factory.createProxy(SAFE_SINGLETON, setupData));
        console.log("Gnosis Safe deployed at:", safeAddr);
        deployedSafe = safeAddr;

        // 4) Deploy Eligibility & Toggle modules
        eligibilityModule = new EligibilityModule(safeAddr);
        toggleModule      = new ToggleModule(safeAddr);

        console.log("EligibilityModule at:", address(eligibilityModule));
        console.log("ToggleModule at:     ", address(toggleModule));

        // 5) Mint Top Hat to the Safe (via the Safe)
        {
            bytes memory data = abi.encodeWithSelector(
                Hats.mintTopHat.selector,
                safeAddr,
                "ipfs://bafkreih3vqseitn7pijlkl2jcawbjrhae3dfb2pakqtgd4epvxxfulwoqq",
                ""
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }
        adminHatId = uint256(hats.lastTopHatId()) << 224;
        console.log("adminHatId (TopHat) =", adminHatId);

        // 6) Create child Hats

        // Arbiter
        {
            arbiterHatId = hats.getNextId(adminHatId);
            bytes memory data = abi.encodeWithSelector(
                Hats.createHat.selector,
                adminHatId,
                "ipfs://bafkreicbhbvddt2f475inukntzh6n72ehm4iyljstyyjsmizdsojmbdase",
                uint32(2),
                address(eligibilityModule),
                address(toggleModule),
                true,
                ""
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }
            
        // DAO
        {
            daoHatId = hats.getNextId(adminHatId);
            bytes memory data = abi.encodeWithSelector(
                Hats.createHat.selector,
                adminHatId,
                "ipfs://bafkreic2f5b6ykdvafs5nhkouruvlql73caou5etgdrx67yt6ofp6pwf24",
                uint32(2),
                address(eligibilityModule),
                address(toggleModule),
                true,
                ""
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }

        // System
        {
            systemHatId = hats.getNextId(adminHatId);
            bytes memory data = abi.encodeWithSelector(
                Hats.createHat.selector,
                adminHatId,
                "ipfs://bafkreie2vxohaw7cneknlwv6hq7h4askkv6jfcadho6efz5bxfx66fqu3q",
                uint32(2),
                address(eligibilityModule),
                address(toggleModule),
                true,
                ""
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }

        // Pauser
        {
            pauserHatId = hats.getNextId(adminHatId);
            bytes memory data = abi.encodeWithSelector(
                Hats.createHat.selector,
                adminHatId,
                "ipfs://bafkreiczfbtftesggzcfnumcy7rfru665a77uyznbabdk5b6ftfo2hvjw4",
                uint32(2),
                address(eligibilityModule),
                address(toggleModule),
                true,
                ""
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }

        console.log("Arbiter Hat ID:", arbiterHatId);
        console.log("DAO Hat ID:    ", daoHatId);
        console.log("System Hat ID: ", systemHatId);
        console.log("Pauser Hat ID: ", pauserHatId);

        // 7) Deploy HatsSecurityContext & set role hats
        securityContext = new HatsSecurityContext(address(hats), adminHatId);
        console.log("HatsSecurityContext at:", address(securityContext));

        // 8) Configure eligibility + toggle modules
        {
            // Hat rules
            bytes memory data = abi.encodeWithSelector(
                EligibilityModule.setHatRules.selector,
                adminHatId,
                true,
                true
            );
            execTransaction(safeAddr, address(eligibilityModule), 0, data);

            data = abi.encodeWithSelector(
                EligibilityModule.setHatRules.selector,
                arbiterHatId,
                true,
                true
            );
            execTransaction(safeAddr, address(eligibilityModule), 0, data);

            data = abi.encodeWithSelector(
                EligibilityModule.setHatRules.selector,
                daoHatId,
                true,
                true
            );
            execTransaction(safeAddr, address(eligibilityModule), 0, data);

            data = abi.encodeWithSelector(
                EligibilityModule.setHatRules.selector,
                systemHatId,
                true,
                true
            );
            execTransaction(safeAddr, address(eligibilityModule), 0, data);

            data = abi.encodeWithSelector(
                EligibilityModule.setHatRules.selector,
                pauserHatId,
                true,
                true
            );
            execTransaction(safeAddr, address(eligibilityModule), 0, data);
        }
        {
            // Toggle hat "active"
            bytes memory data = abi.encodeWithSelector(
                ToggleModule.setHatStatus.selector,
                adminHatId,
                true
            );
            execTransaction(safeAddr, address(toggleModule), 0, data);

            data = abi.encodeWithSelector(
                ToggleModule.setHatStatus.selector,
                arbiterHatId,
                true
            );
            execTransaction(safeAddr, address(toggleModule), 0, data);

            data = abi.encodeWithSelector(
                ToggleModule.setHatStatus.selector,
                daoHatId,
                true
            );
            execTransaction(safeAddr, address(toggleModule), 0, data);

            data = abi.encodeWithSelector(
                ToggleModule.setHatStatus.selector,
                systemHatId,
                true
            );
            execTransaction(safeAddr, address(toggleModule), 0, data);

            data = abi.encodeWithSelector(
                ToggleModule.setHatStatus.selector,
                pauserHatId,
                true
            );
            execTransaction(safeAddr, address(toggleModule), 0, data);
        }

        // 9) Mint hats to relevant addresses
        {
            // Arbiter
            bytes memory data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                arbiterHatId,
                adminAddress1
            );
            execTransaction(safeAddr, address(hats), 0, data);

            data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                arbiterHatId,
                adminAddress2
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }
        {
            // DAO
            bytes memory data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                daoHatId,
                adminAddress1
            );
            execTransaction(safeAddr, address(hats), 0, data);

            data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                daoHatId,
                adminAddress2
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }
        {
            // System
            bytes memory data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                systemHatId,
                adminAddress1
            );
            execTransaction(safeAddr, address(hats), 0, data);

            data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                systemHatId,
                adminAddress2
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }
        {
            // Pauser
            bytes memory data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                pauserHatId,
                adminAddress1
            );
            execTransaction(safeAddr, address(hats), 0, data);

            data = abi.encodeWithSelector(
                Hats.mintHat.selector,
                pauserHatId,
                adminAddress2
            );
            execTransaction(safeAddr, address(hats), 0, data);
        }

        // 10) Set role hats in the HatsSecurityContext
        {
            bytes memory data = abi.encodeWithSelector(
                HatsSecurityContext.setRoleHat.selector,
                Roles.ARBITER_ROLE,
                arbiterHatId
            );
            execTransaction(safeAddr, address(securityContext), 0, data);

            data = abi.encodeWithSelector(
                HatsSecurityContext.setRoleHat.selector,
                Roles.DAO_ROLE,
                daoHatId
            );
            execTransaction(safeAddr, address(securityContext), 0, data);

            data = abi.encodeWithSelector(
                HatsSecurityContext.setRoleHat.selector,
                Roles.SYSTEM_ROLE,
                systemHatId
            );
            execTransaction(safeAddr, address(securityContext), 0, data);

            data = abi.encodeWithSelector(
                HatsSecurityContext.setRoleHat.selector,
                Roles.PAUSER_ROLE,
                pauserHatId
            );
            execTransaction(safeAddr, address(securityContext), 0, data);
        }

        vm.stopBroadcast();

        console.log("-----------------------------------------------");
        console.log("Hats deployed at:             ", address(hats));
        console.log("EligibilityModule deployed at:", address(eligibilityModule));
        console.log("ToggleModule deployed at:     ", address(toggleModule));
        console.log("HatsSecurityContext deployed: ", address(securityContext));
        console.log("Gnosis Safe deployed at:      ", deployedSafe);
        console.log("Finished Hats deployment script");
        console.log("-----------------------------------------------");

        // Return the newly deployed safe address to the caller script
        return(deployedSafe, address(securityContext));
    }
}
