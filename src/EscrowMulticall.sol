// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEscrowContract 
{
    function placeSinglePayment(PaymentInput calldata payment) external;
}

/* Encapsulates information about an incoming payment
*/
struct PaymentInput
{
    address currency; //token address, or 0x0 for native 
    address contractAddress;
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
}

contract EscrowMulticall
{
    constructor() {}

    function multicall(PaymentInput[] calldata payments) external payable {
        for (uint256 n=0; n<payments.length; n++) {
            PaymentInput memory payment = payments[n];

            uint256 amount = payment.amount;

            if (payment.currency == address(0)) {
                    //check that the amount matches
                if (msg.value < amount)
                    revert("InsufficientAmount");

                //then forward the payment & call to the contract 
                (bool success, ) = payment.contractAddress.call{value: msg.value}(
                    abi.encodeWithSignature("placeSinglePayment((address,address,bytes32,address,address,uint256))", payment)
                );
            } 
            else {
                    //transfer to self 
                IERC20 token = IERC20(payment.currency);
                if (!token.transferFrom(msg.sender, address(this), amount))
                    revert('TokenPaymentFailed'); 

                //then forward the payment & call to the contract 
                token.approve(payment.contractAddress, amount);

                (bool success, ) = payment.contractAddress.call{value: msg.value}(
                    abi.encodeWithSignature("placeSinglePayment((address,address,bytes32,address,address,uint256))", payment)
                );
            }
        }
    }

    receive() external payable {}
}