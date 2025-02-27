// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@hats-protocol/Hats.sol";
import "./ISecurityContext.sol";

interface IHatsSecurityContext is ISecurityContext {
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
