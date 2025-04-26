import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // 1. Deploy Vault (no await .deployed)
  const Vault = await ethers.getContractFactory("Vault");
  const vault = await Vault.deploy(deployer.address);
  console.log("Vault deployed at:", vault.target);

  // 2. Deploy CBBCFactory
  const CBBCFactory = await ethers.getContractFactory("CBBCFactory");
  const factory = await CBBCFactory.deploy(vault.target, deployer.address);
  console.log("CBBCFactory deployed at:", factory.target);

  // 3. Deploy MockOracle (for testing)
  const MockOracle = await ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy(ethers.parseUnits("58000", 8)); // New parseUnits
  console.log("MockOracle deployed at:", mockOracle.target);

  // 4. Create a CBBC Product
  const createTx = await factory.createCBBC(
    "BTC Bull 30JUN25",        // name
    "BTCBULL",                  // symbol
    mockOracle.target,          // oracle
    vault.target,               // vault
    ethers.parseUnits("60000", 8), // strikePrice
    ethers.parseUnits("50000", 8), // callLevel
    Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // expiry
    true,                       // isBull
    ethers.parseUnits("0.2", 18), // marginRatio (20%)
    ethers.parseUnits("58000", 8), // initialPrice
    deployer.address,            // issuer
    deployer.address             // initialOwner (CBBC ownable)
  );
  const receipt = await createTx.wait();
  console.log("CBBC created via Factory!");

  const event = receipt.logs?.find((e) => e.fragment?.name === "CBBCIssued");
  const cbbcAddress = event?.args?.cbbcAddress;
  console.log("CBBC Token deployed at:", cbbcAddress);

  console.log("✅ Deployment complete!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
