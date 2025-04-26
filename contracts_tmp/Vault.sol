// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is Ownable {
    mapping(address => uint256) public margins;
    mapping(address => bool) public liquidated;

    event MarginDeposited(address indexed cbbc, uint256 amount);
    event MarginLiquidated(address indexed cbbc);
    event SettlementHandled(address indexed cbbc);
    event KnockOutHandled(address indexed cbbc);

    function depositMargin(address cbbc) external payable onlyOwner {
        margins[cbbc] += msg.value;
        emit MarginDeposited(cbbc, msg.value);
    }

    function checkMargin(address cbbc, uint256 requiredMargin) external {
        require(!liquidated[cbbc], "Already liquidated");

        if (margins[cbbc] < requiredMargin) {
            liquidated[cbbc] = true;
            emit MarginLiquidated(cbbc);
        }
    }

    function handleKnockOut(address cbbc) external {
        emit KnockOutHandled(cbbc);
    }

    function handleSettlement(address cbbc) external {
        emit SettlementHandled(cbbc);
    }
}
