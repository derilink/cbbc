// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Vault.sol";
import "./CBBC.sol";

contract CBBCSwap is Ownable {
    IERC20 public stablecoin;
    Vault public vault;
    CBBC public cbbc;
    uint256 public premiumPerToken;

    event PremiumUpdated(uint256 newPremium);
    event CBBCBought(address buyer, uint256 amount, uint256 cost);

    constructor(address _stablecoin, address _vault, address _cbbc, uint256 _initialPremium) {
        stablecoin = IERC20(_stablecoin);
        vault = Vault(_vault);
        cbbc = CBBC(_cbbc);
        premiumPerToken = _initialPremium;
    }

    function updatePremium(uint256 newPremium) external onlyOwner {
        require(newPremium > 0, "Invalid premium");
        premiumPerToken = newPremium;
        emit PremiumUpdated(newPremium);
    }

    function buy(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        uint256 totalCost = (premiumPerToken * amount) / 1e18;
        require(
            stablecoin.transferFrom(msg.sender, address(this), totalCost),
            "USDC transfer failed"
        );

        stablecoin.approve(address(vault), totalCost);
        vault.depositPremium(address(cbbc), totalCost);

        cbbc.mint(msg.sender, amount);
        emit CBBCBought(msg.sender, amount, totalCost);
    }
}
