// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title ISystemSettings
 * 
 * Holds global settings, to be set only by privileged parties, for all escrow contracts to read.
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
interface ISystemSettings {
    /**
     * Gets the address of the vault to which fees are paid.
     */
    function vaultAddress() external view returns (address);

    /**
     * Gets the amount in basis points, indicating the portion of payments to be separated and 
     * paid to the vault as fees.
     */
    function feeBps() external view returns (uint256);
}