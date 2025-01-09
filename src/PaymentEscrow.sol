// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./HasSecurityContext.sol"; 
import "./ISystemSettings.sol"; 
import "./CarefulMath.sol";
import "./PaymentInput.sol";
import "./IEscrowContract.sol";
import "./inc/token/ERC20/IERC20.sol";
import "./Roles.sol";

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
    bool private autoReleaseFlag;
    bool public paused;

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

    event PaymentRefunded (
        bytes32 indexed paymentId, 
        uint256 amount 
    );

    modifier whenNotPaused() {
        require(!paused, 'Paused');
        _;
    }

    modifier whenPaused() {
        require(paused, 'NotPaused');
        _;
    }
    
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
    constructor(IHatsSecurityContext securityContext, ISystemSettings settings_, bool autoRelease) {
        _setSecurityContext(securityContext);
        settings = settings_;
        autoReleaseFlag = autoRelease;
    }
    
    /**
     * Helper function to handle token transfer
     * 
     * @param currency The token address
     * @param from The sender address
     * @param amount The amount to transfer
     * @return bool True if the transfer is successful, false otherwise
     */
    function _handleTokenTransfer(address currency, address from, uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(currency);
        return token.transferFrom(from, address(this), amount);
    }

    /**
     * Helper function to validate payment input
     * 
     * @param input The payment input
     */
    function _validatePaymentInput(PaymentInput calldata input) internal pure {
        require(input.amount > 0, "InvalidAmount");
        require(input.receiver != address(0), "InvalidReceiver");
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
    function placePayment(PaymentInput calldata paymentInput) public payable whenNotPaused {
        _validatePaymentInput(paymentInput);

        // Check for existing payment
        require(payments[paymentInput.id].id != paymentInput.id, "DuplicatePayment");

        // Handle payment transfer
        if (paymentInput.currency == address(0)) {
            require(msg.value == paymentInput.amount, "InvalidAmount");
        } else {
            require(_handleTokenTransfer(paymentInput.currency, msg.sender, paymentInput.amount), "TokenPaymentFailed");
        }

        // Store payment
        Payment storage payment = payments[paymentInput.id];
        payment.payer = paymentInput.payer;
        payment.receiver = paymentInput.receiver;
        payment.currency = paymentInput.currency;
        payment.amount = paymentInput.amount;
        payment.id = paymentInput.id;
        payment.receiverReleased = autoReleaseFlag;

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
     * Gives consent to release the escrow. Caller must be a party to the escrow (either payer, 
     * receiver, or arbiter).  

     * Reverts: 
     * - 'Unauthorized': if caller is neither payer, receiver, nor arbiter.

     * Emits: 
     * - {PaymentEscrow-ReleaseAssentGiven} 
     * - {PaymentEscrow-EscrowReleased} 
     * - {PaymentEscrow-PaymentTransferred} 
     * - {PaymentEscrow-PaymentTransferFailed} 
     * 
     * @param paymentId A unique payment id
     */
    function releaseEscrow(bytes32 paymentId) external whenNotPaused {
        Payment storage payment = payments[paymentId];

        if (msg.sender != payment.receiver && 
            msg.sender != payment.payer && 
            !securityContext.hasRole(Roles.ARBITER_ROLE, msg.sender))
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
            if (securityContext.hasRole(Roles.ARBITER_ROLE, msg.sender)) {
                if (!payment.payerReleased) {
                    payment.payerReleased = true;
                    emit ReleaseAssentGiven(paymentId, msg.sender, 3);
                }
            }

            _releaseEscrowPayment(paymentId);
        }
    }

    /**
     * Partially or fully refunds the payment. Can be called only by arbiter or receiver. 

     * Reverts: 
     * - 'Unauthorized': if caller is neither receiver nor arbiter.
     * Reverts: 
     * - 'AmountExceeded': if the amount to refund is greater than the remaining amount for the 
     * order (the original amount minus any previous refunds).

     * Emits: 
     * - {PaymentEscrow-PaymentTransferred} 
     * - {PaymentEscrow-PaymentTransferFailed} 
     * - {PaymentEscrow-PaymentRefunded} 
     * 
     * @param paymentId Identifies the payment to refund. 
     * @param amount The amount to refund, can't be more than the remaining amount.
     */
    function refundPayment(bytes32 paymentId, uint256 amount) external whenNotPaused {
        Payment storage payment = payments[paymentId]; 
        require(payment.released == false, "Payment already released");
        if (payment.amount > 0 && payment.amountRefunded <= payment.amount) {

            //who has permission to refund? either the receiver or the arbiter
            if (payment.receiver != msg.sender && !securityContext.hasRole(Roles.ARBITER_ROLE, msg.sender))
                revert("Unauthorized");

            uint256 activeAmount = payment.amount - payment.amountRefunded; 

            if (amount > activeAmount) 
                revert("AmountExceeded");

            //transfer amount back to payer 
            if (amount > 0) {
                if (_transferAmount(payment.id, payment.payer, payment.currency, amount)) {
                    payment.amountRefunded += amount;
                    emit PaymentRefunded(paymentId, amount);
                }
            }
        }
    }

    /**
     * Sets the default value of the receiverReleased flag on new payments. 
     * True: new payments will automatically have receiverReleased set to TRUE. The ramification of 
     * this is that the escrow does not need to be released by the receiver. 
     * False: new payments will have receiverReleased set to false; this means that the escrow requires
     * both parties to release it.
     */
    function setAutoReleaseFlag(bool value) external onlyRole(Roles.SYSTEM_ROLE) {
        autoReleaseFlag = value;
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


    //NON-PUBLIC METHODS

    // Helper function to calculate fee and remaining amount
    function _calculateFeeAndAmount(uint256 amount) internal view returns (uint256 fee, uint256 amountToPay) {
        fee = 0;
        uint256 feeBps = _getFeeBps();
        if (feeBps > 0) {
            fee = CarefulMath.mulDiv(amount, feeBps, 10000);
            if (fee > amount) {
                fee = 0;
            }
        }
        amountToPay = amount - fee;
    }

    // Helper function to handle fee transfer
    function _handleFeeTransfer(bytes32 paymentId, address currency, uint256 fee) internal returns (bool) {
        if (fee == 0) return true;
        return _transferAmount(paymentId, _getvaultAddress(), currency, fee);
    }

    function _releaseEscrowPayment(bytes32 paymentId) internal {
        Payment storage payment = payments[paymentId];
        if (!payment.payerReleased || !payment.receiverReleased || payment.released) {
            return;
        }

        uint256 amount = payment.amount - payment.amountRefunded;
        (uint256 fee, uint256 amountToPay) = _calculateFeeAndAmount(amount);

        // If there's no amount to pay but there is a fee, or if the transfer succeeds
        if ((amountToPay == 0 && fee > 0) || 
            _transferAmount(payment.id, payment.receiver, payment.currency, amountToPay)) {
            
            // Handle fee transfer
            if (_handleFeeTransfer(payment.id, payment.currency, fee)) {
                payment.released = true;
                emit EscrowReleased(paymentId, amountToPay, fee);
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
                revert("PaymentTransferFailed");
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

    //TODO: no longer necessary?
    receive() external payable {}
}