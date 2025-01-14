// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PaymentInput.sol";

/**
 * @title IEscrowContract
 */
interface IEscrowContract 
{
    function placePayment(PaymentInput calldata payment) external payable;
}