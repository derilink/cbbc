// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Vault.sol";
import "./CBBC.sol";

contract RFQSwap is Ownable {
    IERC20 public stablecoin;
    Vault public vault;
    CBBC public cbbc;

    mapping(address => bool) public isIssuer;
    mapping(bytes32 => uint256) public remainingAmount; // Quote hash => unfilled quantity
    mapping(bytes32 => bool) public acceptedBids; // Bid hash => accepted or not

    event QuoteExecuted(
        address indexed buyer,
        uint256 amount,
        uint256 totalCost
    );
    event BidAccepted(
        address indexed bidder,
        uint256 amount,
        uint256 totalCost
    );
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);

    constructor(address _stablecoin, address _vault, address _cbbc) {
        stablecoin = IERC20(_stablecoin);
        vault = Vault(_vault);
        cbbc = CBBC(_cbbc);
    }

    struct Quote {
        address buyer;
        uint256 amount;
        uint256 premiumPerToken;
        uint256 expiry;
        uint256 nonce;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 bidPremiumPerToken;
        uint256 expiry;
        uint256 nonce;
    }

    // Add or remove issuer
    function addIssuer(address issuer) external onlyOwner {
        isIssuer[issuer] = true;
        emit IssuerAdded(issuer);
    }

    function removeIssuer(address issuer) external onlyOwner {
        isIssuer[issuer] = false;
        emit IssuerRemoved(issuer);
    }

    // Hashing
    function hashQuote(Quote memory quote) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    quote.buyer,
                    quote.amount,
                    quote.premiumPerToken,
                    quote.expiry,
                    quote.nonce
                )
            );
    }

    function hashBid(Bid memory bid) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    bid.bidder,
                    bid.amount,
                    bid.bidPremiumPerToken,
                    bid.expiry,
                    bid.nonce
                )
            );
    }

    function buyPartial(
        Quote memory quote,
        bytes memory issuerSignature,
        uint256 amountToBuy
    ) external {
        require(msg.sender == quote.buyer, "Not authorized buyer");
        require(block.timestamp <= quote.expiry, "Quote expired");

        bytes32 quoteHash = hashQuote(quote);

        if (remainingAmount[quoteHash] == 0) {
            address signer = recoverSigner(quoteHash, issuerSignature);
            require(isIssuer[signer], "Invalid issuer signature");
            remainingAmount[quoteHash] = quote.amount;
        }

        require(
            remainingAmount[quoteHash] >= amountToBuy,
            "Not enough available amount"
        );

        remainingAmount[quoteHash] -= amountToBuy;

        uint256 totalCost = (amountToBuy * quote.premiumPerToken) / 1e18;

        require(
            stablecoin.transferFrom(msg.sender, address(this), totalCost),
            "USDC transfer failed"
        );

        stablecoin.approve(address(vault), totalCost);
        vault.depositPremium(address(cbbc), totalCost);

        cbbc.mint(msg.sender, amountToBuy);

        emit QuoteExecuted(msg.sender, amountToBuy, totalCost);
    }

    function acceptBid(Bid memory bid, bytes memory issuerSignature) external {
        require(msg.sender == bid.bidder, "Only bidder can accept");
        require(block.timestamp <= bid.expiry, "Bid expired");

        bytes32 bidHash = hashBid(bid);
        require(!acceptedBids[bidHash], "Bid already accepted");
        acceptedBids[bidHash] = true;

        address signer = recoverSigner(bidHash, issuerSignature);
        require(isIssuer[signer], "Invalid issuer signature");

        uint256 totalCost = (bid.amount * bid.bidPremiumPerToken) / 1e18;

        require(
            stablecoin.transferFrom(msg.sender, address(this), totalCost),
            "USDC transfer failed"
        );

        stablecoin.approve(address(vault), totalCost);
        vault.depositPremium(address(cbbc), totalCost);

        cbbc.mint(msg.sender, bid.amount);

        emit BidAccepted(msg.sender, bid.amount, totalCost);
    }

    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) public pure returns (address) {
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\\x19Ethereum Signed Message:\\n32", hash)
        );
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
