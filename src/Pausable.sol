// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./HasSecurityContext.sol"; 
import "./CarefulMath.sol";
import "./interfaces/ISystemSettings.sol";
import "./interfaces/IPolyEscrow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PolyEscrow
 */
contract Pausable is HasSecurityContext
{
    bool public paused;

    modifier whenNotPaused() {
        require(!paused, 'Paused');
        _;
    }

    modifier whenPaused() {
        require(paused, 'NotPaused');
        _;
    }

    //TODO: add paused/unpaused events

    constructor(ISecurityContext securityContext) {
        _setSecurityContext(securityContext);
    }

    /**
     * Pauses the contract.
     */
    function pause() external whenNotPaused onlyRole(Roles.SYSTEM_ROLE) {
        paused = true;
    }

    /**
     * Unpauses the contract, if paused.
     */
    function unpause() external whenPaused onlyRole(Roles.SYSTEM_ROLE) {
        paused = false;
    }
}