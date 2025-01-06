// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./ISecurityContext.sol";

/**
 * @title HasSecurityContext
 *
 * Abstract base contract for contracts using Hats-based security context.
 */
abstract contract HasSecurityContext {
    ISecurityContext public securityContext;

    // Predefined roles
    bytes32 public constant ADMIN_ROLE = 0x0;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SYSTEM_ROLE = keccak256("SYSTEM_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    // Error messages
    error UnauthorizedAccess(bytes32 roleId, address addr);
    error ZeroAddressArgument();

    // Event emitted when security context is updated
    event SecurityContextSet(address indexed caller, address indexed securityContext);

    /**
     * @notice Modifier to restrict access to specific roles.
     * @param role The `bytes32` identifier of the role.
     */
    modifier onlyRole(bytes32 role) {
        if (!securityContext.hasRole(role, msg.sender)) {
            revert UnauthorizedAccess(role, msg.sender);
        }
        _;
    }

    // Returns the address of the caller. Can be overridden for meta-transactions or proxies.
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

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
}
