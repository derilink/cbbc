# CBBC System (Hardhat Project)

This project deploys a full CBBC (Callable Bull/Bear Contract) system on Base Testnet.

## Components

- MockOracle: Mock BTC price feed
- Vault: Margin management
- CBBCFactory: Factory to mass-issue CBBC tokens
- CBBC: ERC20 CBBC token contracts

## How to Deploy on Base Testnet

1. Install dependencies:

```
npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers @openzeppelin/contracts

npm install
```

2. Configure `hardhat.config.js` to connect to Base Sepolia Testnet:

```
require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: "0.8.19",
  networks: {
    base_sepolia: {
      url: "https://sepolia.base.org",
      accounts: [PRIVATE_KEY] // add your wallet private key
    }
  }
};
```

3. Deploy:

```
npx hardhat run scripts/deploy-mock-cbbc.js --network base_sepolia
```

4. Verify deployments!

## Notes

- Use MockOracle to simulate price movements
- Manually trigger `checkCallEvent()` to simulate knock-outs
- Adjust margin thresholds via Vault
