import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const usdcAddress = "0xE0f2a422f2F2e4dB6276E65f2cc0c46EfDE2b6A7"; // Base Sepolia USDC

  const Vault = await ethers.getContractFactory("Vault");
  const vault = await Vault.deploy(usdcAddress, deployer.address);
  console.log("Vault deployed at:", vault.target);

  const CBBCFactory = await ethers.getContractFactory("CBBCFactory");
  const factory = await CBBCFactory.deploy(vault.target, deployer.address);
  console.log("CBBCFactory deployed at:", factory.target);

  const MockOracle = await ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy(ethers.parseUnits("58000", 8));
  console.log("MockOracle deployed at:", mockOracle.target);

  const createTx = await factory.createCBBC(
    "BTC Bull 30JUN25",
    "BTCBULL",
    mockOracle.target,
    vault.target,
    ethers.parseUnits("60000", 8),
    ethers.parseUnits("50000", 8),
    Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
    true,
    ethers.parseUnits("0.2", 18),
    ethers.parseUnits("58000", 8),
    deployer.address,
    deployer.address
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
