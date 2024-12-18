// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../../src/ISecurityContext.sol";

/**
 * @title MockSecurityContext
 * 
 * A mock version of SecurityContext for testing. 
 * Allows arbitrary granting/revoking of roles without restrictions.
 * Useful for simulating different security scenarios without complex AccessControl logic.
 */
contract MockSecurityContext is ISecurityContext {
    // For simplicity store role membership in a nested mapping
    mapping(bytes32 => mapping(address => bool)) private _roles;

    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    constructor(bytes32[] memory initialRoles, address[] memory initialAccounts) {
        // Grant specified roles to specified accounts at construction
        require(initialRoles.length == initialAccounts.length, "Array length mismatch");
        for (uint i = 0; i < initialRoles.length; i++) {
            _roles[initialRoles[i]][initialAccounts[i]] = true;
        }
    }

    function hasRole(bytes32 role, address account) external view override returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external {
        _roles[role][account] = true;
        emit RoleGranted(role, account);
    }
    
    function revokeRole(bytes32 role, address account) external {
        _roles[role][account] = false;
        emit RoleRevoked(role, account);
    }
}
