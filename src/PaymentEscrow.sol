// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./HasSecurityContext.sol"; 
import "./ISystemSettings.sol"; 
import "./CarefulMath.sol";
import "./PaymentInput.sol";
import "./IEscrowContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Payment 
{
    bytes32 id;
    address payer;
    address receiver;
    uint256 amount;
    uint256 amountRefunded;
    bool payerReleased;
    bool receiverReleased;
    bool released;
    address currency; //token address, or 0x0 for native 
}

/**
 * @title PaymentEscrow
 * 
 * Takes in funds from marketplace, extracts a fee, and batches the payments for transfer
 * to the appropriate parties, holding the funds in escrow in the meantime. 
 * 
 * @author John R. Kosinski
 * LoadPipe 2024
 * All rights reserved. Unauthorized use prohibited.
 */
contract PaymentEscrow is HasSecurityContext, IEscrowContract
{
    ISystemSettings private settings;
    mapping(bytes32 => Payment) private payments;

    //EVENTS 

    event PaymentReceived (
        bytes32 indexed paymentId,
        address indexed to,
        address from, 
        address currency, 
        uint256 amount 
    );

    event ReleaseAssentGiven (
        bytes32 indexed paymentId,
        address assentingAddress,
        //TODO: make enum
        uint8 assentType // 1 = payer, 2 = receiver, 3 = arbiter
    );

    event EscrowReleased (
        bytes32 indexed paymentId,
        uint256 amount,
        uint256 fee
    );

    event PaymentTransferred (
        bytes32 indexed paymentId, 
        address currency, 
        uint256 amount 
    );

    event PaymentTransferFailed (
        bytes32 indexed paymentId, 
        address currency, 
        uint256 amount 
    );
    
    /**
     * Constructor. 
     * 
     * Emits: 
     * - {HasSecurityContext-SecurityContextSet}
     * 
     * Reverts: 
     * - {ZeroAddressArgument} if the securityContext address is 0x0. 
     * 
     * @param securityContext Contract which will define & manage secure access for this contract. 
     * @param settings_ Address of contract that holds system settings. 
     */
    constructor(ISecurityContext securityContext, ISystemSettings settings_) {
        _setSecurityContext(securityContext);
        settings = settings_;
    }
    
    /**
     * Allows multiple payments to be processed. 
     * 
     * Reverts: 
     * - 'InsufficientAmount': if amount of native ETH sent is not equal to the declared amount. 
     * - 'TokenPaymentFailed': if token transfer fails for any reason (e.g. insufficial allowance)
     * - 'DuplicatePayment': if payment id exists already 
     * 
     * Emits: 
     * - {PaymentEscrow-PaymentReceived} 
     * 
     * @param paymentInput Payment inputs
     */
    function placePayment(PaymentInput calldata paymentInput) public payable {
        address currency = paymentInput.currency; 
        uint256 amount = paymentInput.amount;


        if (currency == address(0)) {
                //check that the amount matches
            if (msg.value < amount)
                revert("InsufficientAmount");
        } 
        else {
                //transfer to self 
            IERC20 token = IERC20(currency);
            if (!token.transferFrom(msg.sender, address(this), amount)){
                revert("TokenPaymentFailed"); 
            }
        }

        //check for existing, and revert if exists already
        if (payments[paymentInput.id].id == paymentInput.id) {
            revert("DuplicatePayment");
        }

        //add payments to internal map, emit events for each individual payment
        Payment storage payment = payments[paymentInput.id];
        payment.payer = paymentInput.payer;
        payment.receiver = paymentInput.receiver;
        payment.currency = paymentInput.currency;
        payment.amount = paymentInput.amount;
        payment.id = paymentInput.id;

        //emit event
        emit PaymentReceived(
            payment.id, 
            payment.receiver, 
            payment.payer, 
            payment.currency, 
            payment.amount
        );
    }

    /**
     * Returns the payment data specified by id. 
     * 
     * @param paymentId A unique payment id
     */
    function getPayment(bytes32 paymentId) public view returns (Payment memory) {
        return payments[paymentId];
    }

    /**
     * Gives assent to release the escrow. Caller must be a party to the escrow (either payer, 
     * receiver, or arbiter).  

     * Reverts: 
     * - 'Unauthorized': if caller is neither payer, receiver, nor arbiter.
     * - 'AmountExceeded': if the specified amount is more than the available amount to refund.

     * Emits: 
     * - {PaymentEscrow-ReleaseAssentGiven} 
     * - {PaymentEscrow-EscrowReleased} 
     * 
     * @param paymentId A unique payment id
     */
    function releaseEscrow(bytes32 paymentId) external {
        Payment storage payment = payments[paymentId];

        if (msg.sender != payment.receiver && 
            msg.sender != payment.payer && 
            !securityContext.hasRole(ARBITER_ROLE, msg.sender))
        {
            revert("Unauthorized");
        }

        if (payment.amount > 0) {
            if (payment.receiver == msg.sender) {
                if (!payment.receiverReleased) {
                    payment.receiverReleased = true;
                    emit ReleaseAssentGiven(paymentId, msg.sender, 1);
                }
            }
            if (payment.payer == msg.sender) {
                if (!payment.payerReleased) {
                    payment.payerReleased = true;
                    emit ReleaseAssentGiven(paymentId, msg.sender, 2);
                }
            }
            if (securityContext.hasRole(ARBITER_ROLE, msg.sender)) {
                if (!payment.payerReleased) {
                    payment.payerReleased = true;
                    emit ReleaseAssentGiven(paymentId, msg.sender, 3);
                }
            }

            _releaseEscrowPayment(paymentId);
        }
    }

    //TODO: need event here
    /**
     * Partially or fully refunds the payment. Can be called only by arbiter or receiver. 
     * 
     * @param paymentId Identifies the payment to refund. 
     * @param amount The amount to refund, can't be more than the remaining amount.
     */
    function refundPayment(bytes32 paymentId, uint256 amount) external {
        Payment storage payment = payments[paymentId]; 
        if (payment.amount > 0 && payment.amountRefunded <= payment.amount) {

            //who has permission to refund? either the receiver or the arbiter
            if (payment.receiver != msg.sender && !securityContext.hasRole(ARBITER_ROLE, msg.sender))
                revert("Unauthorized");

            uint256 activeAmount = payment.amount - payment.amountRefunded; 

            if (amount > activeAmount) 
                revert("AmountExceeded");

            //transfer amount back to payer 
            if (amount > 0) {
                if (_transferAmount(payment.id, payment.payer, payment.currency, amount))
                    payment.amountRefunded += amount;
            }
        }
    }


    function _releaseEscrowPayment(bytes32 paymentId) internal {
        Payment storage payment = payments[paymentId];
        if (payment.payerReleased && payment.receiverReleased && !payment.released) {
            uint256 amount = payment.amount - payment.amountRefunded;

            //break off fee 
            uint256 fee = 0;
            uint256 feeBps = _getFeeBps();
            if (feeBps > 0) {
                fee = CarefulMath.mulDiv(amount, feeBps, 10000);
                if (fee > amount)
                    fee = 0;
            }
            uint256 amountToPay = amount - fee; 

            //transfer funds 
            if (!payment.released) {
                if (
                    (amountToPay == 0 && fee > 0) || 
                    _transferAmount(
                        payment.id, 
                        payment.receiver, 
                        payment.currency, 
                        amountToPay
                    )
                ) {
                    //also transfer fee to vault 
                    if (fee > 0) {
                        if (_transferAmount(
                            payment.id, 
                            _getvaultAddress(), 
                            payment.currency, 
                            fee
                        )) { 
                            payment.released = true;
                            emit EscrowReleased(paymentId, amountToPay, fee);
                        }
                    }
                    else {
                        payment.released = true;
                        emit EscrowReleased(paymentId, amountToPay, fee);
                    }
                }
            }
        }
    }

    function _transferAmount(bytes32 paymentId, address to, address tokenAddressOrZero, uint256 amount) internal returns (bool) {
        bool success = false; 

        if (amount > 0) {
            if (tokenAddressOrZero == address(0)) {
                (success,) = payable(to).call{value: amount}("");
            } 
            else {
                IERC20 token = IERC20(tokenAddressOrZero); 
                success = token.transfer(to, amount);
            }

            if (success) {
                emit PaymentTransferred(paymentId, tokenAddressOrZero, amount);
            }
            else {
                emit PaymentTransferFailed(paymentId, tokenAddressOrZero, amount);
            }
        }

        return success;
    }

    function _getFeeBps() internal view returns (uint256) {
        if (address(settings) != address(0)) 
            return settings.feeBps();

        return 0;
    }

    function _getvaultAddress() internal view returns (address) {
        if (address(settings) != address(0)) 
            return settings.vaultAddress();

        return address(0);
    }

    receive() external payable {}
}