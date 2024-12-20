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
    uint256 user1_in_escrow_balance;

    uint256 user2_initial_balance;
    uint256 user2_in_escrow_balance;

    uint256 user3_initial_balance;
    uint256 user3_in_escrow_balance;
    
    constructor() {
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings);

        user1_initial_balance = user1.balance;
        user2_initial_balance = user2.balance;
        user3_initial_balance = user3.balance;
    }

    function placePayment1(uint256 amount, bytes32 id) public {
        PaymentInput memory input = PaymentInput(address(0), id, user1, msg.sender, amount);
        escrow.placePayment(input);
    }

    function placePayment2(uint256 amount, bytes32 id) public {
        PaymentInput memory input = PaymentInput(address(0), id, user2, msg.sender, amount);
        escrow.placePayment(input);
    }

    function placePayment3(uint256 amount, bytes32 id) public {
        PaymentInput memory input = PaymentInput(address(0), id, user3, msg.sender, amount);
        escrow.placePayment(input);
    }

    function refund1(bytes32 id, uint256 amount) public {
        escrow.refundPayment(id, amount);
    }

    function release1(bytes32 id) public {
        escrow.releaseEscrow(id);
    }
    
    function echidna_invariant() public view returns (bool) {
        return true;
    }
}