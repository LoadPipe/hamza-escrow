// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// A token contract that conditionally fails on transfers by returning false instead of reverting.
contract FailingToken is IERC20 {
    string public name = "Failing Token";
    string public symbol = "FAIL";
    uint8 public decimals = 18;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 private _totalSupply = 1_000_000 ether;
    bool public failTransfers = false; // Controls whether transfers should fail by returning false

    constructor() {
        balances[msg.sender] = _totalSupply;
    }

    // including this excludes from coverage report foundry
    function test() public {}

    function setFailTransfers(bool _fail) external {
        failTransfers = _fail;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (failTransfers) {
            // Instead of reverting, return false to indicate failure.
            return false;
        }

        uint256 senderBalance = balances[msg.sender];
        require(senderBalance >= amount, "Insufficient balance");
        unchecked {
            balances[msg.sender] = senderBalance - amount;
        }
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        if (failTransfers) {
            // Return false to indicate failure.
            return false;
        }

        uint256 allowed = allowances[sender][msg.sender];
        require(allowed >= amount, "Transfer amount exceeds allowance");
        
        uint256 senderBalance = balances[sender];
        require(senderBalance >= amount, "Insufficient balance");

        unchecked {
            allowances[sender][msg.sender] = allowed - amount;
            balances[sender] = senderBalance - amount;
        }

        balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
}
