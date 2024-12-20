// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract test_test  {
    address constant user0 = address(0); 
    address constant user1 = address(0x10000); 
    address constant user2 = address(0x20000); 
    address constant user3 = address(0x30000); 
    address constant userDeadbeef = address(0xDeaDBeef);
    
    constructor() {
    }
    
    function echidna_invariant() public pure returns (bool) {
        return true;
    }
}