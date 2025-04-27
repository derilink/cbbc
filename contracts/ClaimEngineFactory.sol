// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ClaimEngine.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClaimEngineFactory is Ownable {
    mapping(address => address) public cbbcToClaimEngine;

    event ClaimEngineDeployed(
        address indexed cbbc,
        address indexed claimEngine
    );

    constructor(address initialOwner) Ownable(initialOwner) {}

    function deployClaimEngine(
        address stablecoin,
        address cbbc,
        uint256 totalPayout
    ) external onlyOwner returns (address) {
        ClaimEngine engine = new ClaimEngine(stablecoin, cbbc, totalPayout);
        cbbcToClaimEngine[cbbc] = address(engine);

        emit ClaimEngineDeployed(cbbc, address(engine));
        return address(engine);
    }
}
