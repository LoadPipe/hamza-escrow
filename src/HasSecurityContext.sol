// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/ISecurityContext.sol";
import "./Roles.sol";

/**
 * @title HasSecurityContext
 */
abstract contract HasSecurityContext {
    ISecurityContext public securityContext;

    bool private initialized = false;

    error UnauthorizedAccess(bytes32 roleId, address addr);
    error ZeroAddressArgument();

    event SecurityContextSet(address indexed caller, address indexed securityContext);

    modifier onlyRole(bytes32 role) {
        if (!securityContext.hasRole(role, msg.sender)) {
            revert UnauthorizedAccess(role, msg.sender);
        }
        _;
    }

    function getSecurityContext() external virtual view returns (ISecurityContext) {
        return securityContext;
    }

    function setSecurityContext(ISecurityContext _securityContext) external virtual onlyRole(Roles.ADMIN_ROLE) {
        _setSecurityContext(_securityContext);
    }

    function _setSecurityContext(ISecurityContext _securityContext) internal {
        if (address(_securityContext) == address(0)) revert ZeroAddressArgument();

        if (!initialized) {
            initialized = true;
        } else {
            if (!_securityContext.hasRole(Roles.ADMIN_ROLE, msg.sender)) {
                revert("Caller is not admin");
            }
        }

        if (securityContext != _securityContext) {
            securityContext = _securityContext;
            emit SecurityContextSet(msg.sender, address(_securityContext));
        }
    }
}
