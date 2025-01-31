// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPurchaseTracker {
    function recordPurchase(bytes32 paymentId, address seller, address buyer, uint256 amount) external;
}
