// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/SecurityContext.sol";
import "../src/SystemSettings.sol";

contract test_drain  {
    address constant admin = address(0x00001); 
    address constant user1 = address(0x10000); 
    address constant user2 = address(0x20000); 
    address constant user3 = address(0x30000); 
    address constant userDeadbeef = address(0xDeaDBeef);


    address constant vault = address(0x50000); 

    PaymentEscrow escrow;
    SecurityContext securityContext;
    SystemSettings systemSettings;

    uint256 user1_initial_balance;
    uint256 user1_paid_out;
    uint256 user1_in_escrow_balance;

    uint256 user2_initial_balance;
    uint256 user2_paid_out;
    uint256 user2_in_escrow_balance;

    uint256 escrow_id1 = 0;
    uint256 escrow_id2 = 9999999999999999999999999;
    uint256 call_count = 0;
    
    constructor() {
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings);

        user1_initial_balance = user1.balance;
        user2_initial_balance = user2.balance;
    }

    function placePayment1(uint256 amount) public {
        if (msg.sender != user1 && amount > 0) {
            call_count++;
            escrow_id1 += 1;
            PaymentInput memory input = PaymentInput(address(0), bytes32(escrow_id1), user1, msg.sender, amount);
            user1_in_escrow_balance += amount;
            //(bool success, ) = address(escrow).call{value: amount}(
            //        abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
            //);
            address(user1).call{value:amount};
            escrow.releaseEscrow(bytes32(escrow_id1));
        }
    }

/*
    function placePayment2(uint256 amount) public {
        if (msg.sender != user1) {
            escrow_id2 += 1;
            PaymentInput memory input = PaymentInput(address(0), bytes32(escrow_id2), user2, msg.sender, amount);
            user1_in_escrow_balance += amount;
            (bool success, ) = address(escrow).call{value: amount}(
                    abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
            );
            address(user1).call{value: amount};
            escrow.releaseEscrow(bytes32(escrow_id2));
        }
    }*/

    function refund1(uint256 amount) public {
        //escrow.refundPayment(bytes32(escrow_id1), amount);
    }

    function refund2(uint256 amount) public {
        //escrow.refundPayment(bytes32(escrow_id2), amount);
    }

    function release1() public {
        //escrow.releaseEscrow(bytes32(escrow_id1));
    }

    function release2() public {
        //escrow.releaseEscrow(bytes32(escrow_id2));
    }
    
    function echidna_balance_check1() public view returns (bool) {
        //return user1.balance >0 &&  user1.balance == user1_initial_balance;
        if (call_count > 0) {
            return user1.balance > user1_initial_balance;
        }

        return true;
    }
    
    function echidna_balance_check2() public view returns (bool) {
        return user2.balance == user2_initial_balance;
    }
}