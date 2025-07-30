// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ArbitrationModule} from "../src/ArbitrationModule.sol";
import {PolyEscrow, CreateEscrowInput, PaymentInput} from "../src/PolyEscrow.sol";
import {SecurityContext} from "../src/SecurityContext.sol";
import {SystemSettings} from "../src/SystemSettings.sol";
import {ArbitrationType, ArbitrationStatus} from "../src/interfaces/IArbitrationModule.sol";
import {ISecurityContext} from "../src/interfaces/ISecurityContext.sol";

contract AutoExecuteTest is Test {
    ArbitrationModule internal arbitrationModule;
    PolyEscrow internal polyEscrow;
    SecurityContext internal securityContext;
    SystemSettings internal systemSettings;
    
    address internal admin = address(0x1);
    address internal payer = address(0x2);
    address internal receiver = address(0x3);
    address internal arbiter = address(0x4);
    address internal vaultAddress = address(0x5);
    
    bytes32 internal escrowId = bytes32("test-escrow");
    
    function setUp() public {
        vm.startPrank(admin);
        
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(
            ISecurityContext(securityContext),
            vaultAddress,
            0
        );
        
        arbitrationModule = new ArbitrationModule();
        polyEscrow = new PolyEscrow(ISecurityContext(securityContext), systemSettings, arbitrationModule);
        
        address[] memory arbiters = new address[](1);
        arbiters[0] = arbiter;
        
        CreateEscrowInput memory input = CreateEscrowInput({
            id: escrowId,
            payer: payer,
            receiver: receiver,
            arbiters: arbiters,
            arbitersRequired: 1,
            amount: 1000,
            currency: address(0),
            startTime: block.timestamp,
            endTime: block.timestamp + 86400,
            arbitrationModule: arbitrationModule
        });
        
        polyEscrow.createEscrow(input);
        vm.stopPrank();
        
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        polyEscrow.placePayment{value: 1000}(PaymentInput({
            escrowId: escrowId,
            currency: address(0),
            amount: 1000
        }));
    }
    
    function testAutoExecuteFalse() public {
        vm.recordLogs();
        vm.prank(payer);
        arbitrationModule.proposeArbitration(polyEscrow, escrowId, ArbitrationType.REFUND, 500, false);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 proposalId = entries[0].topics[1];
        
        vm.prank(arbiter);
        arbitrationModule.voteArbitration(polyEscrow, proposalId, true);
        
        assertEq(uint(arbitrationModule.getProposal(proposalId).status), uint(ArbitrationStatus.ACCEPTED));
        assertFalse(arbitrationModule.getProposal(proposalId).autoExecute);
    }
    
    function testAutoExecuteTrue() public {
        vm.recordLogs();
        vm.prank(payer);
        arbitrationModule.proposeArbitration(polyEscrow, escrowId, ArbitrationType.REFUND, 500, true);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 proposalId = entries[0].topics[1];
        
        vm.prank(arbiter);
        arbitrationModule.voteArbitration(polyEscrow, proposalId, true);
        
        assertEq(uint(arbitrationModule.getProposal(proposalId).status), uint(ArbitrationStatus.EXECUTED));
        assertTrue(arbitrationModule.getProposal(proposalId).autoExecute);
    }
}