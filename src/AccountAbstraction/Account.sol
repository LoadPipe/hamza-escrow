// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import 'hardhat/console.sol';

contract Account is BaseAccount {
    address public owner;
    address public _entryPoint;
    uint256 public counter;

    event StateModified (
        address indexed addr,
        uint256 state
    );

    constructor(address _owner, address _entryPointAddr) {
        console.log("constructor for Account");
        owner = _owner;
        _entryPoint = _entryPointAddr;
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }

    /// implement your authentication logic here
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal override virtual returns (uint256 validationData) {

        // 1. Recover signer address from signature and userOpHash
        //address signer = ECDSA.recover(userOpHash, userOp.signature);

        // 2. Validate signer is the owner
        //require(signer == owner, "Invalid signer");

        // 3. Validate nonce (simplified example)
        //require(userOp.nonce == getNonce(), "Invalid nonce");

        // Return validation data (e.g., VALIDATION_SUCCESS)
        console.log('SIGNATURE IS VALID');
        console.log('Validate: MY ADDRESS IS');
        console.logAddress(address(this));
        return 0; // Or a specific value indicating success
    }

    function modifyState() external {
        counter = counter+1;
        console.log('ModifyState: MY ADDRESS IS');
        console.logAddress(address(this));

        emit StateModified(address(this), counter);
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }
}