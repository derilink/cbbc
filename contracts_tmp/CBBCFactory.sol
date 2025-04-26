// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CBBC.sol";

contract CBBCFactory is Ownable {
    address[] public allCBBCTokens;
    address public vault;

    event CBBCIssued(address indexed cbbcAddress, address indexed issuer);

    constructor(address _vault) {
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
        uint256 initialPrice
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
            msg.sender
        );
        cbbc.transferOwnership(msg.sender);
        allCBBCTokens.push(address(cbbc));
        emit CBBCIssued(address(cbbc), msg.sender);
        return address(cbbc);
    }

    function getAllCBBCTokens() external view returns (address[] memory) {
        return allCBBCTokens;
    }
}
