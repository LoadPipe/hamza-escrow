// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/ISecurityContext.sol";
import "./Roles.sol";

//TODO: implement this with actual security

/**
 * @title SecurityContext
 */
contract SecurityContext is ISecurityContext {

    // Mapping of `bytes32` roles to their corresponding Hat IDs
    mapping(bytes32 => uint256) public roleToHatId;

    constructor(address adminAddress) {
    }

    function hasRole(bytes32 /*role*/, address /*account*/) external pure override returns (bool) {
        return true;
    }
}
