// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./HasSecurityContext.sol";
import "./ISystemSettings.sol";

/**
 * @title SystemSettings
 *
 * Holds global settings, to be set only by privileged parties, for all escrow contracts to read.
 */
contract SystemSettings is HasSecurityContext, ISystemSettings {
    address private _vaultAddress;
    uint256 private _feeBps;

    // EVENTS
    event VaultAddressChanged(address newAddress, address changedBy);
    event FeeBpsChanged(uint256 newValue, address changedBy);

    /**
     * Address of the vault to which fees are paid.
     */
    function vaultAddress() external view returns (address) {
        return _vaultAddress;
    }

    /**
     * Amount in basis points, indicating the portion of payments to be separated and paid to the vault as fees.
     */
    function feeBps() external view returns (uint256) {
        return _feeBps;
    }

    /**
     * Constructor.
     *
     * Emits:
     * - {HasSecurityContext-SecurityContextSet}
     *
     * Reverts:
     * - {ZeroAddressArgument} if the securityContext address is 0x0.
     * - 'InvalidVaultAddress' if the given vault address is zero.
     *
     * @param securityContext Contract which will define & manage secure access for this contract.
     * @param vaultAddress_ Recipient of the extracted fees.
     * @param feeBps_ Amount of fees charged in basis points.
     */
    constructor(ISecurityContext securityContext, address vaultAddress_, uint256 feeBps_) {
        _setSecurityContext(securityContext);
        if (vaultAddress_ == address(0)) {
            revert("InvalidVaultAddress");
        }
        _vaultAddress = vaultAddress_;
        _feeBps = feeBps_;
    }

    /**
     * Sets the address to which fees are sent.
     *
     * Emits:
     * - {VaultAddressChanged}
     *
     * Reverts:
     * - 'UnauthorizedAccess' if caller is not authorized as DAO_ROLE.
     * - 'InvalidValue' if the given address is invalid (zero address).
     *
     * @param vaultAddress_ The new address.
     */
    function setVaultAddress(address vaultAddress_) public onlyRole(DAO_ROLE) {
        if (_vaultAddress != vaultAddress_) {
            if (vaultAddress_ == address(0)) {
                revert("InvalidValue");
            }
            _vaultAddress = vaultAddress_;
            emit VaultAddressChanged(_vaultAddress, msg.sender);
        }
    }

    /**
     * Sets the fee basis points (feeBps).
     *
     * Emits:
     * - {FeeBpsChanged}
     *
     * Reverts:
     * - 'UnauthorizedAccess' if caller is not authorized as DAO_ROLE.
     *
     * @param feeBps_ The new value for fee in basis points.
     */
    function setFeeBps(uint256 feeBps_) public onlyRole(DAO_ROLE) {
        if (_feeBps != feeBps_) {
            _feeBps = feeBps_;
            emit FeeBpsChanged(_feeBps, msg.sender);
        }
    }
}
