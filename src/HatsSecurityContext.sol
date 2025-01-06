// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

// Import Hats Protocol
import "hats-protocol/src/Hats.sol";
import "./ISecurityContext.sol";

/**
 * @title HatsSecurityContext
 *
 * A security context implementation using Hats Protocol.
 * Provides role-based security through Hats Protocol.
 */
contract HatsSecurityContext is ISecurityContext {
    // Hats Protocol instance
    Hats public hats;

    // Mapping of `bytes32` roles to their corresponding Hat IDs
    mapping(bytes32 => uint256) public roleToHatId;

    /**
     * @notice Initializes the HatsSecurityContext with the Hats Protocol contract and roles.
     * @param _hats The address of the Hats Protocol contract.
     * @param _adminHatId The Hat ID corresponding to the ADMIN_ROLE.
     */
    constructor(address _hats, uint256 _adminHatId) {
        require(_hats != address(0), "Hats address cannot be zero");

        hats = Hats(_hats);

        // Map the ADMIN_ROLE to the specified Hat ID
        roleToHatId[ADMIN_ROLE] = _adminHatId;
    }

    /**
     * @notice Check if an account has a specific role.
     * @param role The `bytes32` identifier of the role.
     * @param account The address to check for the role.
     * @return True if the account has the role, otherwise false.
     */
    function hasRole(bytes32 role, address account)
        external
        view
        override
        returns (bool)
    {
        uint256 hatId = roleToHatId[role];
        if (hatId == 0) return false; // Role not defined
        return hats.isWearerOfHat(account, hatId);
    }

    /**
     * @notice Set a Hat ID for a specific role.
     * @param role The `bytes32` identifier of the role.
     * @param hatId The Hat ID to associate with the role.
     */
    function setRoleHat(bytes32 role, uint256 hatId) external {
        // Only ADMIN_ROLE can modify role mappings
        require(
            hats.isWearerOfHat(msg.sender, roleToHatId[ADMIN_ROLE]),
            "Caller is not admin"
        );
        roleToHatId[role] = hatId;
    }
}
