// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/ISecurityContext.sol";
import "../Types.sol";

interface IPolyEscrow {
    function getSecurityContext() external view returns (ISecurityContext);
    function getEscrow(bytes32 escrowId) external view returns (Escrow memory);
    function placePayment(PaymentInput calldata paymentInput) external payable;
}