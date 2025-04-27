// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICBBC is IERC20 {
    function totalSupply() external view returns (uint256);
}

contract ClaimEngine is Ownable {
    IERC20 public stablecoin;
    ICBBC public cbbc;
    uint256 public totalPayout;
    uint256 public snapshotSupply;

    mapping(address => bool) public claimed;

    event Claimed(address indexed user, uint256 amount);

    constructor(address _stablecoin, address _cbbc, uint256 _totalPayout) {
        stablecoin = IERC20(_stablecoin);
        cbbc = ICBBC(_cbbc);
        totalPayout = _totalPayout;
        snapshotSupply = ICBBC(_cbbc).totalSupply();
    }

    function claim() external {
        require(!claimed[msg.sender], "Already claimed");
        uint256 userBalance = cbbc.balanceOf(msg.sender);
        require(userBalance > 0, "No CBBC tokens");

        uint256 payoutAmount = (totalPayout * userBalance) / snapshotSupply;
        require(payoutAmount > 0, "Nothing to claim");

        claimed[msg.sender] = true;

        // Transfer CBBC tokens to burn them
        require(
            cbbc.transferFrom(msg.sender, address(this), userBalance),
            "Burn transfer failed"
        );
        IERC20(address(cbbc)).transfer(address(0), userBalance);

        require(
            stablecoin.transfer(msg.sender, payoutAmount),
            "USDC payout failed"
        );

        emit Claimed(msg.sender, payoutAmount);
    }
}
