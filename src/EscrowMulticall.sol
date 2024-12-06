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
    address contractAddress;
    address currency; //token address, or 0x0 for native 
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
}

struct SinglePaymentInput
{
    address currency; //token address, or 0x0 for native 
    bytes32 id;
    address receiver;
    address payer;
    uint256 amount;
}

contract EscrowMulticall
{
    constructor() {}

    function multipay(PaymentInput[] calldata payments) external payable {
        for (uint256 n=0; n<payments.length; n++) {
            PaymentInput memory payment = payments[n];

            uint256 amount = payment.amount;

            if (payment.currency == address(0)) {
                    //check that the amount matches
                if (msg.value < amount)
                    revert("InsufficientAmount");

                //then forward the payment & call to the contract 
                SinglePaymentInput memory input = SinglePaymentInput(payment.currency, payment.id, payment.receiver, payment.payer, payment.amount);
                (bool success, ) = payment.contractAddress.call{value: msg.value}(
                    abi.encodeWithSignature("placeSinglePayment((address,bytes32,address,address,uint256))", input)
                );

                if (!success) {
                    revert();
                }
            } 
            else {
                    //transfer to self 
                IERC20 token = IERC20(payment.currency);
                if (!token.transferFrom(msg.sender, address(this), amount))
                    revert('TokenPaymentFailed'); 

                //then forward the payment & call to the contract 
                token.approve(payment.contractAddress, amount);

                SinglePaymentInput memory input = SinglePaymentInput(payment.currency, payment.id, payment.receiver, payment.payer, payment.amount);
                (bool success, ) = payment.contractAddress.call{value: msg.value}(
                    abi.encodeWithSignature("placeSinglePayment((address,bytes32,address,address,uint256))", input)
                );

                if (!success) {
                    revert();
                }
            }
        }
    }

    receive() external payable {}
}