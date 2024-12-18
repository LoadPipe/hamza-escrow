// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Context.sol"; 
import "./ISecurityContext.sol"; 

/**
 * @title HasSecurityContext 
 * 
 * This is an abstract base class for contracts whose security is managed by { SecurityContext }. It exposes 
 * the modifier which calls back to the associated { SecurityContext } contract. 
 * 
 * See also { SecurityContext }
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
abstract contract HasSecurityContext is Context { 
    ISecurityContext public securityContext; 
    
    //security roles 
    bytes32 public immutable ADMIN_ROLE;
    bytes32 public PAUSER_ROLE = keccak256("PAUSER_ROLE");     //TODO: needed?
    bytes32 public SYSTEM_ROLE = keccak256("SYSTEM_ROLE");     //TODO: not needed
    bytes32 public APPROVER_ROLE = keccak256("APPROVER_ROLE"); //TODO: not needed?
    bytes32 public REFUNDER_ROLE = keccak256("REFUNDER_ROLE"); //TODO: not needed?
    bytes32 public ARBITER_ROLE = keccak256("ARBITER_ROLE");
    bytes32 public DAO_ROLE = keccak256("DAO_ROLE");
    
    //thrown when the onlyRole modifier reverts 
    error UnauthorizedAccess(bytes32 roleId, address addr); 
    
    //thrown if zero-address argument passed for securityContext
    error ZeroAddressArgument(); 
    
    //emitted when setSecurityContext has been called 
    event SecurityContextSet(address caller, address securityContext);

    event RoleUpdated(bytes32 oldRole, bytes32 newRole);
    
    //Restricts function calls to callers that have a specified security role only 
    modifier onlyRole(bytes32 role) {
        if (!securityContext.hasRole(role, _msgSender())) {
            revert UnauthorizedAccess(role, _msgSender());
        }
        _;
    }
    /**
    * @dev Allows an authorized caller to update a role.
     * Reverts: 
     * - {UnauthorizedAccess}: if caller is not authorized 
     * - {InvalidHat}: if the new role is not a child of the topHat (ADMIN_ROLE)
     * - {ZeroAddressArgument}: if the address passed is 0x0 
     * 
     * @param role The role to update. 
     * @param newRole The new role to set. 
     */
    function updateRole(bytes32 role, bytes32 newRole) external onlyRole(ADMIN_ROLE) {
        _updateRole(role, newRole);
    }

    function _updateRole(bytes32 role, bytes32 newRole) internal {
        //cannot be zero
        if (newRole == bytes32(0)) {
            revert ZeroAddressArgument();
        }
        //TODO:must be a child of the topHat (ADMIN_ROLE)
        // need to figure out how to check this, I think I need to travaerse up the tree
        // by checking the 'level' of the hat and then finding the local admin at that level
        // and then walk up the tree until I arrive at the tippytop hat. 
        // might be easier to ask spencer and co for help if there is an easier way

        //update role
        if (role == ARBITER_ROLE) {
            ARBITER_ROLE = newRole;
        } else if (role == PAUSER_ROLE) {
            PAUSER_ROLE = newRole;
        } else if (role == SYSTEM_ROLE) {
            SYSTEM_ROLE = newRole;
        } else if (role == APPROVER_ROLE) {
            APPROVER_ROLE = newRole;
        } else if (role == REFUNDER_ROLE) {
            REFUNDER_ROLE = newRole;
        } else if (role == DAO_ROLE) {
            DAO_ROLE = newRole;
        }

        emit RoleUpdated(role, newRole);

    }
    
    /**
     * Allows an authorized caller to set the securityContext address. 
     * 
     * Reverts: 
     * - {UnauthorizedAccess}: if caller is not authorized 
     * - {ZeroAddressArgument}: if the address passed is 0x0
     * - 'Address: low-level delegate call failed' (if `_securityContext` is not legit)
     * 
     * @param _securityContext Address of an ISecurityContext. 
     */
    function setSecurityContext(ISecurityContext _securityContext) external onlyRole(ADMIN_ROLE) {
        _setSecurityContext(_securityContext);
    }
    
    /**
     * This call helps to check that a given address is a legitimate SecurityContext contract, by 
     * attempting to call one of its read-only methods. If it fails, this function will revert. 
     * 
     * @param _securityContext The address to check & verify 
     */
    function _setSecurityContext(ISecurityContext _securityContext) internal {
        
        //address can't be zero
        if (address(_securityContext) == address(0)) 
            revert ZeroAddressArgument(); 
            
        //this line will fail if security context is invalid address
        _securityContext.hasRole(ADMIN_ROLE, address(this)); 
        
        if (securityContext != _securityContext) {
            //set the security context
            securityContext = _securityContext;
            
            //emit event
            emit SecurityContextSet(_msgSender(), address(_securityContext));
        }
    }
    
    //future-proof, as this is inherited by upgradeable contracts
    uint256[50] private __gap;
}