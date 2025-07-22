// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./HasSecurityContext.sol"; 
import "./Pausable.sol";
import "./CarefulMath.sol";
import "./interfaces/ISystemSettings.sol";
import "./interfaces/IPolyEscrow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//the properties needed to create a new escrow
struct CreateEscrowInput {
    bytes32 id; // Unique identifier for the escrow
    address payer; // The address of the payer
    address receiver; // The address of the receiver
    address[] arbiters; // The addresses of the arbiters
    uint8 arbitersRequired; // The number of arbiters consent required to release or refund the escrow in absence of payer consent
    uint256 amount; // The total amount of the escrow
    address currency; //The currency addres, 0x0 for native
    uint256 startTime; // The timestamp when the escrow period begins
    uint256 endTime; //The timestamp when the escrow period ends
}

uint256 constant MAX_ARBITERS = 10; // Maximum number of arbiters allowed in an escrow

/**
 * @title PolyEscrow
 */
contract PolyEscrow is HasSecurityContext, Pausable, IPolyEscrow
{
    mapping(bytes32 => Escrow) private escrows;
    ISystemSettings private settings;

    //EVENTS 

    //raised when payment is received
    event PaymentReceived (
        bytes32 indexed escrowId,
        address from, 
        uint256 amount 
    );

    event ReleaseAssentGiven (
        bytes32 indexed escrowId,
        address assentingAddress,
        //TODO: make enum
        uint8 assentType // 1 = payer, 2 = receiver, 3 = arbiter
    );

    event EscrowCreated (
        bytes32 indexed escrowId
    );

    event EscrowFullyPaid (
        bytes32 indexed escrowId, 
        uint256 amount 
    );

    event EscrowReleased (
        bytes32 indexed escrowId,
        uint256 amount,
        uint256 fee
    );

    event EscrowRefunded (
        bytes32 indexed escrowId, 
        uint256 amount 
    );

    event PaymentTransferred (
        bytes32 indexed escrowId, 
        uint256 amount 
    );

    event PaymentTransferFailed (
        bytes32 indexed escrowId, 
        address currency, 
        uint256 amount 
    );
    
    constructor(ISecurityContext securityContext, ISystemSettings systemSettings) Pausable(securityContext) {
        _setSecurityContext(securityContext);
        settings = systemSettings;
    }

    function createEscrow(CreateEscrowInput memory input) public whenNotPaused {
        //EXCEPTION: InvalidEscrow
        require(input.id != 0, "InvalidEscrow");
        //EXCEPTION: InvalidPayer
        require(input.payer != address(0), "InvalidPayer");
        //EXCEPTION: InvalidReceiver
        require(input.receiver != address(0), "InvalidReceiver");
        //EXCEPTION: InvalidAmount
        require(input.amount > 0, "InvalidAmount");
        //EXCEPTION: MaxArbitersExceeded
        //EXCEPTION: InvalidArbiter
        _validateArbiters(input.arbiters, input.payer, input.receiver);
        //EXCEPTION: InvalidToken
        if (input.currency != address(0)) {
            require(_isErc20(input.currency), "InvalidToken");
        }
        //EXCEPTION: InvalidReceiver
        require(input.receiver != input.payer, "InvalidReceiver");

        //TODO: validate input more 

        // EXCEPTION: reject if existing escrow
        require(escrows[input.id].id != input.id, "DuplicateEscrow");

        // Store the escrow
        Escrow memory escrow;
        escrow.id = input.id;
        escrow.payer = input.payer; 
        escrow.receiver = input.receiver;
        escrow.currency = input.currency;
        escrow.amount = input.amount; 
        escrow.arbiters = input.arbiters;
        escrow.arbitersRequired = input.arbitersRequired;
        escrow.startTime = input.startTime;
        escrow.endTime = input.endTime;
        escrow.timestamp = block.timestamp;
        escrow.fullyPaid = false;
        escrow.payerReleased = false;
        escrow.receiverReleased = false;
        escrow.released = false;
        escrow.amountRefunded = 0;
        escrow.amountReleased = 0;
        escrow.amountPaid = 0;
        escrow.status = EscrowStatus.Pending;

        escrows[input.id] = escrow;

        //EVENT: emit event escrow created
        emit EscrowCreated(input.id);
    }

    /**
     * Returns the escrow data specified by unique id. 
     * 
     * @param escrowId A unique escrow id
     */
    function getEscrow(bytes32 escrowId) public view returns (Escrow memory) {
        return escrows[escrowId];
    }

    /**
     * Allows multiple payments to be processed. 
     * 
     * Reverts: 
     * - 'InsufficientAmount': if amount of native ETH sent is not equal to the declared amount. 
     * - 'TokenPaymentFailed': if token transfer fails for any reason (e.g. insufficial allowance)
     * - 'InvalidEscrow': if payment id exists already 
     * 
     * Emits: 
     * - {PaymentEscrow-PaymentReceived} 
     * 
     * @param paymentInput Payment inputs
     */
    function placePayment(PaymentInput calldata paymentInput) public payable whenNotPaused {
        _validatePaymentInput(paymentInput);

        //EXCEPTION: reject if not existing payment
        require(escrows[paymentInput.escrowId].id == paymentInput.escrowId, "InvalidEscrow");

        //TODO: EXCEPTION: reject if escrow not in the correct state to accept payments

        //EXCEPTION: reject the wrong currency
        require (paymentInput.currency == escrows[paymentInput.escrowId].currency, "InvalidCurrency");

        // Handle payment transfer
        if (paymentInput.currency == address(0)) {
            //EXCEPTION: wrong amount rejected
            require(msg.value == paymentInput.amount, "InvalidAmount");
        } else {
            //EXCEPTION: failed payment 
            require(_handleTokenTransfer(paymentInput.currency, msg.sender, paymentInput.amount), "TokenPaymentFailed");
        }

        //get the escrow 
        Escrow storage escrow = escrows[paymentInput.escrowId];

        escrow.amountPaid += paymentInput.amount;
        if (escrow.amountPaid >= escrow.amount) {
            escrow.fullyPaid = true;

            //EVENT: if fully paid, emit fully paid event
            emit EscrowFullyPaid(
                escrow.id,
                escrow.amountPaid
            );
        }

        //EVENT: emit payment received event
        emit PaymentReceived(
            paymentInput.escrowId,
            msg.sender,
            paymentInput.amount
        );
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
     * @param escrowId A unique payment id
     */
    function releaseEscrow(bytes32 escrowId) external whenNotPaused {
        Escrow storage escrow = escrows[escrowId];

        if (msg.sender != escrow.receiver && 
            msg.sender != escrow.payer)
        {
            revert("Unauthorized");
        }

        //TODO: must escrow be fully paid before releasing? 
        //TODO: revert if escrow already released? 
        //TODO: revert if escrow not in a state where it can be released? 
        //TODO: 

        if (escrow.amount > 0) {
            if (escrow.receiver == msg.sender) {
                if (!escrow.receiverReleased) {
                    escrow.receiverReleased = true;
                    emit ReleaseAssentGiven(escrowId, msg.sender, 1);
                }
            }
            if (escrow.payer == msg.sender) {
                if (!escrow.payerReleased) {
                    escrow.payerReleased = true;
                    emit ReleaseAssentGiven(escrowId, msg.sender, 2);
                }
            }
            
            if (_isArbiter(escrow.id, msg.sender)) {
                if (!escrow.payerReleased) {
                    //TODO: check if arbiter count has been met
                    uint8 arbiterAssentCount = 0;
                    for(uint8 n=0; n< escrow.arbiters.length; n++) {
                        if (escrow.arbiters[n] == msg.sender) {
                            escrow.arbiterAssent[n] = true;
                        }
                        
                        if (escrow.arbiterAssent[n]) {
                            arbiterAssentCount++;
                        }

                        if (arbiterAssentCount >= escrow.arbitersRequired) {
                            escrow.payerReleased = true;
                        }
                    }
                    emit ReleaseAssentGiven(escrowId, msg.sender, 3);
                }
            }

            _releaseEscrowPayment(escrowId);
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
     * @param escrowId Identifies the escrow to refund. 
     * @param amount The amount to refund, can't be more than the remaining amount.
     */
    function refundPayment(bytes32 escrowId, uint256 amount) external whenNotPaused {
        Escrow storage escrow = escrows[escrowId]; 
        require(escrow.released == false, "Payment already released");
        if (escrow.amount > 0 && escrow.amountRefunded <= escrow.amount) {

            //who has permission to refund? either the receiver or the arbiter
            if (escrow.receiver != msg.sender && !_isArbiter(escrow.id, msg.sender))
                revert("Unauthorized");

            uint256 activeAmount = escrow.amount - escrow.amountRefunded; 

            if (amount > activeAmount) 
                revert("AmountExceeded");

            //transfer amount back to payer 
            if (amount > 0) {
                if (_transferAmount(escrow.id, escrow.payer, escrow.currency, amount)) {
                    escrow.amountRefunded += amount;
                    emit EscrowRefunded(escrowId, amount);
                }
            }
        }
    }

    function getSecurityContext() external override(IPolyEscrow, HasSecurityContext) view returns (ISecurityContext) {
        return this.getSecurityContext();
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
    function _handleFeeTransfer(bytes32 escrowId, address currency, uint256 fee) internal returns (bool) {
        if (fee == 0) return true;
        return _transferAmount(escrowId, _getVaultAddress(), currency, fee);
    }

    function _releaseEscrowPayment(bytes32 escrowId) internal {
        Escrow storage escrow = escrows[escrowId];
        if (!escrow.payerReleased || !escrow.receiverReleased || escrow.released) {
            return;
        }

        uint256 amount = escrow.amount - escrow.amountRefunded;
        (uint256 fee, uint256 amountToPay) = _calculateFeeAndAmount(amount);

        // If there's no amount to pay but there is a fee, or if the transfer succeeds
        if ((amountToPay == 0 && fee > 0) || 
            _transferAmount(escrow.id, escrow.receiver, escrow.currency, amountToPay)) {
            
            // Handle fee transfer
            if (_handleFeeTransfer(escrow.id, escrow.currency, fee)) {
                escrow.released = true;
                escrow.amountReleased += amountToPay;
                escrow.status = EscrowStatus.Completed;
                emit EscrowReleased(escrowId, amountToPay, fee);
            }
        }
    }

    function _transferAmount(bytes32 escrowId, address to, address tokenAddressOrZero, uint256 amount) internal returns (bool) {
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
                emit PaymentTransferred(escrowId, amount);
            }
            else {
                revert("PaymentTransferFailed");
            }
        }

        return success;
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
    }

    function _isArbiter(bytes32 escrowId, address addr) internal view returns (bool) {
        Escrow memory escrow = escrows[escrowId];
        for (uint256 i = 0; i < escrow.arbiters.length; i++) {
            if (escrow.arbiters[i] == addr) {
                return true;
            }
        }
        return false;
    }

    function _getFeeBps() internal view returns (uint256) {
        if (address(settings) != address(0)) 
            return settings.feeBps();

        return 0;
    }

    function _getVaultAddress() internal view returns (address) {
        if (address(settings) != address(0)) 
            return settings.vaultAddress();

        return address(0);
    }

    function _validateArbiters(address[] memory arbiters, address payer, address receiver) internal pure {
        require(arbiters.length <= MAX_ARBITERS, "MaxArbitersExceeded");

        for (uint256 i = 0; i < arbiters.length; i++) {
            require(arbiters[i] != address(0), "InvalidArbiter");
            for (uint256 j = i + 1; j < arbiters.length; j++) {
                require(arbiters[i] != arbiters[j], "DuplicateArbiter");
            }
            require(arbiters[i] != payer, "InvalidArbiter");
            require(arbiters[i] != receiver, "InvalidArbiter");
        }
    }

    function _isErc20(address tokenAddress) public view returns (bool) {
        if (tokenAddress == address(0)) {
            return false;
        }
        // Check if the address supports the ERC-20 `totalSupply` function
        try IERC20(tokenAddress).totalSupply() returns (uint256) {
            return true; // It has the totalSupply function, likely an ERC-20 token
        } catch {
            return false; // The call failed, it's not a valid ERC-20 token
        }
    }
    

    //TODO: no longer necessary?
    receive() external payable {}
}
