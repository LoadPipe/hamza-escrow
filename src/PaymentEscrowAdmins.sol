// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./security/HasSecurityContext.sol";
import "./security/Roles.sol";
import "./ISystemSettings.sol";
import "./CarefulMath.sol";
import "./PaymentInput.sol";
import "./IEscrowContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPurchaseTracker.sol";
import "./PaymentEscrowAdmins.sol";


enum PaymentEscrowAdminPermission {
    None,
    Release,
    Refund,
    All
}

/**
 * @title PaymentEscrowAdmins
 * 
 * Add-on module for PaymentEscrow; allows PaymentEscrow to appoint admins who can, like the 
 * store owner, refund and release escrows.
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 */
contract PaymentEscrowAdmins
{
    uint8 public constant PermissionRefund = 1; // 00000001
    uint8 public constant PermissionRelease = 1 << 1; // 00000010

    mapping(address => mapping(address => uint8)) public appointedAdmins;

    function grantAdminPermission(address admin, uint8 permission) public {
        appointedAdmins[msg.sender][admin] |= permission;
    }

    function revokeAdminPermission(address admin, uint8 permission) public {
        appointedAdmins[msg.sender][admin] &= ~permission;
    }

    function hasAdminPermission(address owner, address admin, uint8 permission) public view returns (bool) {
        return appointedAdmins[owner][admin] & permission != 0;
    }
}