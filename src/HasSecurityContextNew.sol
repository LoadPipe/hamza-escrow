// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./IHatsSecurityContext.sol";
import "hats-protocol/src/Hats.sol";
import "./Roles.sol";

/**
 * @title HasSecurityContext
 */
abstract contract HasSecurityContextNew {
    IHatsSecurityContext public securityContext;

    error UnauthorizedAccess(bytes32 roleId, address addr);
    error ZeroAddressArgument();

    event SecurityContextSet(address indexed caller, address indexed securityContext);

    modifier onlyRole(bytes32 role) {
        uint256 hatId = securityContext.roleToHatId(role);
        if (!Hats(securityContext.hats()).isWearerOfHat(msg.sender, hatId)) {
            revert UnauthorizedAccess(role, msg.sender);
        }
        _;
    }

    function setSecurityContext(IHatsSecurityContext _securityContext) external onlyRole(Roles.ADMIN_ROLE) {
        _setSecurityContext(_securityContext);
    }

    function _setSecurityContext(IHatsSecurityContext _securityContext) internal {
        if (address(_securityContext) == address(0)) revert ZeroAddressArgument();

        uint256 adminHatId = _securityContext.roleToHatId(Roles.ADMIN_ROLE);
        require(_securityContext.hats().isWearerOfHat(msg.sender, adminHatId), "Caller is not admin");

        if (securityContext != _securityContext) {
            securityContext = _securityContext;
            emit SecurityContextSet(msg.sender, address(_securityContext));
        }
    }
}
