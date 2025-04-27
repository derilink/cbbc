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
    function notionalPerToken() external view returns (uint256);
}

interface IClaimEngineFactory {
    function deployClaimEngine(
        address stablecoin,
        address cbbc,
        uint256 totalPayout
    ) external returns (address);
}

contract Vault is Ownable {
    mapping(address => uint256) public margins;
    mapping(address => uint256) public premiums;
    mapping(address => bool) public liquidated;
    mapping(address => address) public issuers;
    IERC20 public stablecoin;
    address public claimEngineFactory;

    event MarginDeposited(
        address indexed depositor,
        address indexed cbbc,
        uint256 amount
    );
    event PremiumDeposited(
        address indexed buyer,
        address indexed cbbc,
        uint256 amount
    );
    event MarginLiquidated(address indexed cbbc);
    event KnockOutHandled(address indexed cbbc);
    event SettlementHandled(address indexed cbbc);
    event ClaimEngineCreated(address indexed cbbc, address indexed claimEngine);

    constructor(
        address _stablecoin,
        address initialOwner
    ) Ownable(initialOwner) {
        stablecoin = IERC20(_stablecoin);
    }

    function setClaimEngineFactory(address _factory) external onlyOwner {
        claimEngineFactory = _factory;
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

    function depositPremium(address cbbc, uint256 amount) external {
        require(amount > 0, "Premium must be greater than zero");
        require(
            stablecoin.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        premiums[cbbc] += amount;
        emit PremiumDeposited(msg.sender, cbbc, amount);
    }

    function checkMintMargin(address cbbc, uint256 amount) external {
        uint256 price = IPriceOracle(ICBBC(cbbc).oracle()).latestPrice();
        uint256 marginRequiredPerToken = (price *
            ICBBC(cbbc).notionalPerToken()) / 1e18;
        uint256 requiredMargin = marginRequiredPerToken * amount;

        require(
            margins[cbbc] >= requiredMargin,
            "Not enough margin for minting"
        );
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
        uint256 premium = premiums[cbbc];
        margins[cbbc] = 0;
        premiums[cbbc] = 0;

        require(
            stablecoin.transfer(issuer, margin + premium),
            "Refund to issuer failed"
        );
        emit KnockOutHandled(cbbc);
    }

    function handleSettlement(address cbbc) external {
        require(!liquidated[cbbc], "Already liquidated");
        liquidated[cbbc] = true;

        uint256 totalMargin = margins[cbbc] + premiums[cbbc];
        margins[cbbc] = 0;
        premiums[cbbc] = 0;

        uint256 spotPrice = IPriceOracle(ICBBC(cbbc).oracle()).latestPrice();
        uint256 strike = ICBBC(cbbc).strikePrice();
        bool bull = ICBBC(cbbc).isBull();
        uint256 notionalPerToken = ICBBC(cbbc).notionalPerToken();
        uint256 units = ICBBC(cbbc).totalSupply();
        require(units > 0, "No CBBC tokens");

        uint256 priceDiff = 0;
        if (bull && spotPrice > strike) {
            priceDiff = spotPrice - strike;
        } else if (!bull && spotPrice < strike) {
            priceDiff = strike - spotPrice;
        }

        uint256 settlementPerToken = (notionalPerToken * priceDiff) / 1e18;
        uint256 totalSettlement = settlementPerToken * units;

        if (totalSettlement > totalMargin) {
            totalSettlement = totalMargin;
        }

        require(claimEngineFactory != address(0), "ClaimEngineFactory not set");

        address newClaimEngine = IClaimEngineFactory(claimEngineFactory)
            .deployClaimEngine(address(stablecoin), cbbc, totalSettlement);

        require(
            stablecoin.transfer(newClaimEngine, totalSettlement),
            "Transfer to ClaimEngine failed"
        );

        address issuer = issuers[cbbc];
        if (totalMargin > totalSettlement) {
            require(
                stablecoin.transfer(issuer, totalMargin - totalSettlement),
                "Refund to issuer failed"
            );
        }

        emit SettlementHandled(cbbc);
        emit ClaimEngineCreated(cbbc, newClaimEngine);
    }
}
