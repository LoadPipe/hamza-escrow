// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ISecurityContext.sol";
import "hats-protocol/src/Interfaces/IHats.sol";
/**
 * @title SecurityContext 
 * 
 * A contract which provides AccessControl (role-based security) for one or more other contracts. 
 * 
 * This contract itself offers generic role-based security. When associated with another contract (the managed 
 * contract, which holds a reference to this contract's address), the managed contract manages its own security 
 * by calling this contract's hasRole function. Then security for that contract is managed by using this contract's
 * grantRole, revokeRole, and renounceRole functions. 
 * 
 * This contract can manage security for multiple contracts at once. 
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract SecurityContext is AccessControl, ISecurityContext { 
    IHats public immutable hatsContract;
    bytes32 public immutable ADMIN_ROLE;
    
    /**
     * Constructs the instance, granting the initial role(s). 
     */
    constructor(address admin, address _hatsContract, bytes32 _topHat) {
        // hatsContract initialization remains the same since it's immutable
        hatsContract = IHats(_hatsContract);
        ADMIN_ROLE = _topHat;
        // in this construction, the admin role is granted to the admin address AND any wearer  of the topHat
        // to remove the admin, the admin must renounce their role, and the topHat wearer must transfer the hat
        // ideally they transfer the topHat to the DAO.
        _grantRole(ADMIN_ROLE, admin);
    }
    
    /**
     * Returns `true` if `account` has been granted `role`.
     * 
     * @param role The role to query. 
     * @param account Does this account have the specified role?
     */
    function hasRole(bytes32 role, address account) public view virtual override(AccessControl, ISecurityContext) returns (bool) {
        return hatsContract.isWearerOfHat(account, uint256(role));
    }
    
    /**
     * See { AccessControl-renounceRole }
     * 
     * If `account` is the same as caller, ADMIN the role being revoked is ADMIN, then the function 
     * fails quietly with no error. This is to prevent admin from revoking their own adminship, in order 
     * to avoid a case in which there is no admin.
     * 
     * Emits: 
     * - {AccessControl-RoleRevoked}
     * 
     * Reverts: 
     * - {UnauthorizedAccess} if caller does not have the appropriate security role}
     * - 'AccessControl:' if `account` is not the same as the caller. 
     */
    function renounceRole(bytes32 role, address account) public virtual override  {
        if (role != ADMIN_ROLE) {
            super.renounceRole(role, account);
        }
    }
    
    /**
     * See { AccessControl-revokeRole }
     * 
     * Prevents admin from revoking their own admin role, in order to prevent the contracts from being 
     * orphaned, cast adrift on the ocean of life with no admin. 
     * 
     * If `account` is the same as caller, ADMIN the role being revoked is ADMIN, then the function 
     * fails quietly with no error. This is to prevent admin from revoking their own adminship, in order 
     * to avoid a case in which there is no admin.
     * 
     * Emits: 
     * - {AccessControl-RoleRevoked}
     * 
     * Reverts: 
     * - {UnauthorizedAccess} if caller does not have the appropriate security role}
     */
    function revokeRole(bytes32 role, address account) public virtual override  {
        if (account != msg.sender || role != ADMIN_ROLE) {
            super.revokeRole(role, account);
        }
    }
}