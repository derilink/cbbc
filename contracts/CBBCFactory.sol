// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CBBC.sol";

interface IVault {
    function registerIssuer(address cbbc, address issuer) external;
}

contract CBBCFactory is Ownable {
    address[] public allCBBCTokens;
    address public vault;

    event CBBCIssued(address indexed cbbcAddress, address indexed issuer);

    constructor(address _vault, address initialOwner) Ownable(initialOwner) {
        vault = _vault;
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
            issuer // Issuer is owner
        );

        allCBBCTokens.push(address(cbbc));
        IVault(vault).registerIssuer(address(cbbc), issuer);

        emit CBBCIssued(address(cbbc), issuer);
        return address(cbbc);
    }

    function getAllCBBCTokens() external view returns (address[] memory) {
        return allCBBCTokens;
    }
}
