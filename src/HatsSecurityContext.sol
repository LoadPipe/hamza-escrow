// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "hats-protocol/src/Hats.sol";
import "./IHatsSecurityContext.sol";
import "./Roles.sol";

/**
 * @title HatsSecurityContext
 */
contract HatsSecurityContext is IHatsSecurityContext {
    Hats public hats;

    // Mapping of `bytes32` roles to their corresponding Hat IDs
    mapping(bytes32 => uint256) public roleToHatId;

    constructor(address _hats, uint256 _adminHatId) {
        require(_hats != address(0), "Hats address cannot be zero");

        hats = Hats(_hats);
        roleToHatId[Roles.ADMIN_ROLE] = _adminHatId;
    }

    function hasRole(bytes32 role, address account) external view override returns (bool) {
        uint256 hatId = roleToHatId[role];
        if (hatId == 0) return false; // Role not defined
        return hats.isWearerOfHat(account, hatId);
    }

    function setRoleHat(bytes32 role, uint256 hatId) external {
        require(
            hats.isWearerOfHat(msg.sender, roleToHatId[Roles.ADMIN_ROLE]),
            "Caller is not admin"
        );
        roleToHatId[role] = hatId;
    }
}
