// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/SecurityContext.sol";
import "../src/SystemSettings.sol";

contract test_simple  {
    address constant admin = address(0x00001); 
    address constant user1 = address(0x10000); 
    address constant user2 = address(0x20000); 
    address constant user3 = address(0x30000); 
    address constant userDeadbeef = address(0xDeaDBeef);


    address constant vault = address(0x50000); 

    PaymentEscrow escrow;
    SecurityContext securityContext;
    SystemSettings systemSettings;

    uint256 call_count = 0;
    bool first_call = false;
    
    constructor() {
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings);
    }

    function placePayment1(uint256 amount) public {
        first_call = true;
        call_count++;
    }

    function echidna_called() public view returns (bool) {
        return first_call && call_count > 0;
    }

    function echidna_notcalled() public view returns (bool) {
        return !first_call;
    }
}