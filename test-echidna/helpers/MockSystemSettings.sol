// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../../src/ISystemSettings.sol";

/**
 * @title MockSystemSettings
 * 
 * A mock version of SystemSettings for testing. 
 * Allows setting the vault address and feeBps freely.
 */
contract MockSystemSettings is ISystemSettings {
    address private _vaultAddress;
    uint256 private _feeBps;

    event MockVaultAddressChanged(address newAddress);
    event MockFeeBpsChanged(uint256 newFeeBps);

    constructor(address vaultAddress_, uint256 feeBps_) {
        _vaultAddress = vaultAddress_;
        _feeBps = feeBps_;
    }

    function vaultAddress() external view override returns (address) {
        return _vaultAddress;
    }

    function feeBps() external view override returns (uint256) {
        return _feeBps;
    }

    function setVaultAddress(address vaultAddress_) external {
        _vaultAddress = vaultAddress_;
        emit MockVaultAddressChanged(vaultAddress_);
    }

    function setFeeBps(uint256 feeBps_) external {
        _feeBps = feeBps_;
        emit MockFeeBpsChanged(feeBps_);
    }
}
