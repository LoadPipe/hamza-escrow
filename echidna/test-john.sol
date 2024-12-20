// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../src/PaymentEscrow.sol";
import "../src/SecurityContext.sol";
import "../src/SystemSettings.sol";

contract test_john  {
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
    bool call_success = false;
    
    constructor() {
        securityContext = new SecurityContext(admin);
        systemSettings = new SystemSettings(securityContext, vault, 0);
        escrow = new PaymentEscrow(securityContext, systemSettings);
    }

    function placePayment1() public {
        first_call = true;
        uint256 amount = address(this).balance/2;
        
        PaymentInput memory input = PaymentInput(address(0), bytes32(amount), user2, user1, amount);
        (bool success, ) = address(escrow).call{value: amount}(
                abi.encodeWithSignature("placePayment((address,bytes32,address,address,uint256))", input)
        );
    }

    function echidna_sent() public view returns (bool) {
        //if (call_count > 0) {
        //    return address(escrow).balance > 0;
        //}
        
        return address(escrow).balance ==0;
    }

    function echidna_escrow_balance_0() public view returns (bool) {
        return address(escrow).balance == 0 || (first_call && address(escrow).balance > 0);
    }

    function echidna_called() public view returns (bool) {
        return call_count == 0;
    }

    function echidna_balance() public view returns (bool) {
        return user1.balance > 0;
    }

    function echidna_call_success() public view returns (bool) {
        return !call_success;
    }

    function echidna_we_have_balance() public view returns (bool) {
        return address(this).balance > 0;
    }
}