// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SafeTransactionHelper
 * @dev Provides a reusable function for executing Safe transactions.
 */
library SafeTransactionHelper {

    // Helper function to execute a Safe transaction
    function execTransaction(
        address _safe,
        address _to,
        uint256 _value,
        bytes memory _data,
        address _signer
    ) internal returns (address deployedContract) {
        bytes memory signature = abi.encodePacked(
            bytes32(uint256(uint160(_signer))),         // r
            bytes32(0),                               // s
            bytes1(0x01)                              // v=1
        );

        bytes memory safeTxData = abi.encodeWithSignature(
            "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
            _to,
            _value,
            _data,
            uint8(0),        // operation
            0,        // safeTxGas
            0,        // baseGas
            0,        // gasPrice
            address(0),
            address(0),
            signature
        );

        (bool success, bytes memory returnData) = _safe.call(safeTxData);
        require(success, "Safe transaction failed");

        if (returnData.length == 32) {
            deployedContract = abi.decode(returnData, (address));
        } else {
            deployedContract = address(0);
        }
    }
}
