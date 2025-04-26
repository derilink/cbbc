// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockOracle is Ownable {
    uint256 private price;

    event PriceUpdated(uint256 newPrice);

    constructor(
        address initialOwner,
        uint256 _initialPrice
    ) Ownable(initialOwner) {
        price = _initialPrice;
    }

    function latestPrice() external view returns (uint256) {
        return price;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        price = _newPrice;
        emit PriceUpdated(_newPrice);
    }
}
