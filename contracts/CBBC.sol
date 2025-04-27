// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IVault {
    function checkMintMargin(address cbbc, uint256 amount) external;
    function handleKnockOut(address cbbc) external;
    function handleSettlement(address cbbc) external;
    function checkMargin(address cbbc, uint256 requiredMargin) external;
}

interface IPriceOracle {
    function latestPrice() external view returns (uint256);
}

contract CBBC is ERC20, Ownable {
    IPriceOracle public oracle;
    address public vault;
    uint256 public strikePrice;
    uint256 public callLevel;
    uint256 public expiry;
    bool public isBull;
    uint256 public marginRatio;
    uint256 public initialPrice;
    uint256 public notionalPerToken;
    address public issuer;

    bool public knockedOut;
    bool public settled;

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
        uint256 _notionalPerToken,
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
        notionalPerToken = _notionalPerToken;
        issuer = _issuer;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        IVault(vault).checkMintMargin(address(this), amount);
        _mint(to, amount);
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
}
