// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPriceOracle {
    function latestPrice() external view returns (uint256);
}

interface IVault {
    function handleKnockOut(address cbbc) external;
    function handleSettlement(address cbbc) external;
    function checkMargin(address cbbc, uint256 requiredMargin) external;
}

contract CBBC is ERC20, Ownable {
    IPriceOracle public oracle;
    address public vault;
    IERC20 public stablecoin;

    uint256 public strikePrice;
    uint256 public callLevel;
    uint256 public expiry;
    bool public isBull;
    uint256 public marginRatio;
    uint256 public initialPrice;
    address public issuer;

    bool public knockedOut;
    bool public settled;
    bool public readyToClaim;

    mapping(address => bool) public claimed;

    constructor(
        string memory name,
        string memory symbol,
        address _oracle,
        address _vault,
        uint256 _strikePrice,
        uint256 _callLevel,
        uint256 _expiry,
        bool _isBull,
        uint256 _marginRatio,
        uint256 _initialPrice,
        address _issuer,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        oracle = IPriceOracle(_oracle);
        vault = _vault;
        strikePrice = _strikePrice;
        callLevel = _callLevel;
        expiry = _expiry;
        isBull = _isBull;
        marginRatio = _marginRatio;
        initialPrice = _initialPrice;
        issuer = _issuer;
    }

    function setStablecoin(address _stablecoin) external onlyOwner {
        require(address(stablecoin) == address(0), "Already set");
        stablecoin = IERC20(_stablecoin);
    }

    function checkCallEvent() external {
        require(!knockedOut, "Already knocked out");
        uint256 price = oracle.latestPrice();
        if ((isBull && price <= callLevel) || (!isBull && price >= callLevel)) {
            knockedOut = true;
            IVault(vault).handleKnockOut(address(this));
        }
    }

    function checkMargin() external {
        uint256 price = oracle.latestPrice();
        uint256 requiredMargin = (price * marginRatio) / 1e18;
        IVault(vault).checkMargin(address(this), requiredMargin);
    }

    function settle() external {
        require(
            block.timestamp >= expiry || knockedOut,
            "Not expired or knocked out"
        );
        require(!settled, "Already settled");
        settled = true;
        IVault(vault).handleSettlement(address(this));
    }

    function enableClaim() external onlyOwner {
        require(settled, "Not settled yet");
        readyToClaim = true;
    }

    function claimPayout() external {
        require(readyToClaim, "Claim not ready");
        require(!claimed[msg.sender], "Already claimed");
        uint256 holderBalance = balanceOf(msg.sender);
        require(holderBalance > 0, "No CBBC tokens");

        uint256 total = totalSupply();
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        require(contractBalance > 0, "No USDC to claim");

        uint256 payoutAmount = (contractBalance * holderBalance) / total;

        claimed[msg.sender] = true;
        _burn(msg.sender, holderBalance);

        require(
            stablecoin.transfer(msg.sender, payoutAmount),
            "Transfer failed"
        );
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
