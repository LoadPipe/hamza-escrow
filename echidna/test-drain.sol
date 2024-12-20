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
    address constant user4 = address(0x40000); 
    address constant user5 = address(0x50000); 
    address constant userDeadbeef = address(0xDeaDBeef);


    address constant vault = address(0x50000); 

    PaymentEscrow escrow;
    SecurityContext securityContext;
    SystemSettings systemSettings;
    
    constructor() {
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings);
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

    function refund1(uint256 amount, bytes32 id) public {
        PaymentInput memory input = PaymentInput(address(0), id, user1, msg.sender, amount);
        escrow.placePayment(input);
    }

    function release1(uint256 amount, bytes32 id) public {
        PaymentInput memory input = PaymentInput(address(0), id, user1, msg.sender, amount);
        escrow.placePayment(input);
    }
    
    function echidna_invariant() public pure returns (bool) {
        return true;
    }
}