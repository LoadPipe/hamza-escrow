// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./PaymentInput.sol";

/**
 * @title IEscrowContract
 */
interface IEscrowContract 
{
    function placePayment(PaymentInput calldata payment) external payable;
}