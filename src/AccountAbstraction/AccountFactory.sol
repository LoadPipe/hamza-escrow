// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Account.sol";
import "hardhat/console.sol";

contract AccountFactory {
    address public entryPoint; 

    event AccountCreated(address indexed accountAddress);

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
    }

    // A function to create a new Account contract instance with an assigned owner
    function createAccount(address owner) external returns (address) {
        console.log("createAccount, sender is");
        console.logAddress(msg.sender);
        Account acc = new Account(owner, entryPoint);
        emit AccountCreated(address(acc));
        return address(acc); // Returns the address of the newly created Account contract
    }
}