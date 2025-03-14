// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPurchaseTracker {
    function recordPurchase(bytes32 paymentId, address seller, address buyer, uint256 amount, address currency) external;
    function getPurchaseCount(address recipient) external view returns (uint256);
    function getPurchaseAmount(address recipient) external view returns (uint256);
    function getSalesCount(address recipient) external view returns (uint256);
    function getSalesAmount(address recipient) external view returns (uint256);
    function getPurchaseAmountByCurrency(address recipient, address currency) external view returns (uint256);
    function getSalesAmountByCurrency(address recipient, address currency) external view returns (uint256);
}
