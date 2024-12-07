// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./PaymentInput.sol";

interface IEscrowContract 
{
    function placePayment(PaymentInput calldata payment) external payable;
}