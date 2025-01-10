// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/* Encapsulates information about an incoming multicall payment
*/
struct PaymentInput
{
    address currency; //token address, or 0x0 for native 
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
}


/* Encapsulates information about a stored payment in escrow.
*/
struct Payment 
{
    bytes32 id;
    address payer;
    address receiver;
    uint256 amount;
    uint256 amountRefunded;
    bool payerReleased;
    bool receiverReleased;
    bool released;
    address currency; //token address, or 0x0 for native 
}