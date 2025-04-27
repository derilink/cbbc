// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CBBC.sol";

interface IVault {
    function registerIssuer(address cbbc, address issuer) external;
}

contract CBBCFactory is Ownable {
    address[] public allCBBCTokens;
    address public vault;
    address public stablecoin; // USDC address

    event CBBCIssued(address indexed cbbcAddress, address indexed issuer);

    constructor(
        address _vault,
        address _stablecoin,
        address initialOwner
    ) Ownable(initialOwner) {
        vault = _vault;
        stablecoin = _stablecoin;
    }

    function createCBBC(
        string memory name,
        string memory symbol,
        address oracle,
        uint256 strikePrice,
        uint256 callLevel,
        uint256 expiry,
        bool isBull,
        uint256 marginRatio,
        uint256 initialPrice,
        address issuer
    ) external returns (address) {
        CBBC cbbc = new CBBC(
            name,
            symbol,
            oracle,
            vault,
            strikePrice,
            callLevel,
            expiry,
            isBull,
            marginRatio,
            initialPrice,
            issuer,
            issuer // make issuer the owner of CBBC
        );

        allCBBCTokens.push(address(cbbc));

        // 1. Register issuer in Vault
        IVault(vault).registerIssuer(address(cbbc), issuer);

        // 2. Set stablecoin in CBBC
        cbbc.setStablecoin(stablecoin);

        emit CBBCIssued(address(cbbc), issuer);
        return address(cbbc);
    }

    function getAllCBBCTokens() external view returns (address[] memory) {
        return allCBBCTokens;
    }
}
