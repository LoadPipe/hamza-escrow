// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../lib/hats-protocol/src/Hats.sol";

interface IHatsSecurityContext {
    /**
     * @notice Checks if an account has the specified role.
     * @param role The role to query, identified by a `bytes32` role ID.
     * @param account The address to check for the specified role.
     * @return True if the account has the specified role, otherwise false.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @notice Returns the Hat ID associated with a specific role.
     * @param role The role identifier (as a `bytes32` value).
     * @return The Hat ID corresponding to the specified role.
     */
    function roleToHatId(bytes32 role) external view returns (uint256);

    /**
     * @notice Returns the Hats instance associated with the context.
     * @return The Hats contract instance.
     */
    function hats() external view returns (Hats);
}
