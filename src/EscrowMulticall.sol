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

                //TODO: if this call fails, return the money
                if (!success) {
                    (bool returnSuccess, ) = msg.sender.call{value: msg.value}("");

                    //TODO: emit event 
                    if (!returnSuccess){}
                }
            } 
            else {
                    //transfer to self 
                IERC20 token = IERC20(payment.currency);
                if (!token.transferFrom(msg.sender, address(this), amount))
                    revert('TokenPaymentFailed'); 

                //then forward the payment & call to the contract 
                //TODO: handle this call's failure as well 
                token.approve(payment.contractAddress, amount);

                (bool success, ) = payment.contractAddress.call{value: msg.value}(
                    abi.encodeWithSignature("placeSinglePayment((address,address,bytes32,address,address,uint256))", payment)
                );

                //if this call fails, return the money
                if (!success) {
                    //TODO: emit event?
                    token.transfer(msg.sender, amount);
                }
            }
        }
    }

    receive() external payable {}
}