// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AAWallet is BaseAccount {
    address public owner;
    address public _entryPoint;

    constructor(address _owner, address _entryPointAddr) {
        owner = _owner;
        _entryPoint = _entryPointAddr;
    }

    /// implement your authentication logic here
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal override virtual returns (uint256 validationData) {

        // 1. Recover signer address from signature and userOpHash
        address signer = ECDSA.recover(userOpHash, userOp.signature);

        // 2. Validate signer is the owner
        require(signer == owner, "Invalid signer");

        // 3. Validate nonce (simplified example)
        require(userOp.nonce == getNonce(), "Invalid nonce");

        // Return validation data (e.g., VALIDATION_SUCCESS)
        return 0; // Or a specific value indicating success
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }
}