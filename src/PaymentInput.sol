// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

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
