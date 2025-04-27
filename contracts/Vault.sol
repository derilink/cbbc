// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPriceOracle {
    function latestPrice() external view returns (uint256);
}

interface ICBBC {
    function totalSupply() external view returns (uint256);
    function oracle() external view returns (address);
    function strikePrice() external view returns (uint256);
    function initialPrice() external view returns (uint256);
    function isBull() external view returns (bool);
}

contract Vault is Ownable {
    mapping(address => uint256) public margins;
    mapping(address => bool) public liquidated;
    mapping(address => address) public issuers;
    IERC20 public stablecoin;

    event MarginDeposited(
        address indexed depositor,
        address indexed cbbc,
        uint256 amount
    );
    event MarginLiquidated(address indexed cbbc);
    event KnockOutHandled(address indexed cbbc);
    event SettlementHandled(address indexed cbbc);

    constructor(
        address _stablecoin,
        address initialOwner
    ) Ownable(initialOwner) {
        stablecoin = IERC20(_stablecoin);
    }

    function registerIssuer(address cbbc, address issuer) external onlyOwner {
        issuers[cbbc] = issuer;
    }

    function depositMargin(address cbbc, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        require(
            stablecoin.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        margins[cbbc] += amount;
        emit MarginDeposited(msg.sender, cbbc, amount);
    }

    function checkMargin(address cbbc, uint256 requiredMargin) external {
        require(!liquidated[cbbc], "Already liquidated");
        if (margins[cbbc] < requiredMargin) {
            liquidated[cbbc] = true;
            emit MarginLiquidated(cbbc);
        }
    }

    function handleKnockOut(address cbbc) external {
        require(!liquidated[cbbc], "Already liquidated");
        liquidated[cbbc] = true;

        address issuer = issuers[cbbc];
        uint256 margin = margins[cbbc];
        margins[cbbc] = 0;

        require(
            stablecoin.transfer(issuer, margin),
            "Transfer to issuer failed"
        );

        emit KnockOutHandled(cbbc);
    }

    function handleSettlement(address cbbc) external {
        require(!liquidated[cbbc], "Already liquidated");
        liquidated[cbbc] = true;

        uint256 vaultBalance = margins[cbbc];
        margins[cbbc] = 0;

        uint256 spotPrice = IPriceOracle(ICBBC(cbbc).oracle()).latestPrice();
        uint256 strike = ICBBC(cbbc).strikePrice();
        uint256 initial = ICBBC(cbbc).initialPrice();
        bool bull = ICBBC(cbbc).isBull();

        uint256 settlementPerUnit = 0;
        if (bull && spotPrice > strike) {
            settlementPerUnit = spotPrice - strike;
        } else if (!bull && spotPrice < strike) {
            settlementPerUnit = strike - spotPrice;
        }

        uint256 totalSupply = ICBBC(cbbc).totalSupply();
        require(totalSupply > 0, "No CBBC tokens");

        uint256 totalSettlement = (settlementPerUnit * totalSupply) / initial;

        if (totalSettlement >= vaultBalance) {
            stablecoin.transfer(cbbc, vaultBalance);
        } else {
            stablecoin.transfer(cbbc, totalSettlement);
            stablecoin.transfer(issuers[cbbc], vaultBalance - totalSettlement);
        }

        emit SettlementHandled(cbbc);
    }
}
