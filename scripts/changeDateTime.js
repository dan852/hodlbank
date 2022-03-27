const { ethers } = require("hardhat");
const { abi } = require("../artifacts/contracts/HodlBank.sol/HodlBank.json");

async function main() {
  const [signer] = await ethers.provider.listAccounts();

  await ethers.provider.send("evm_increaseTime", [+(3600 * 24 * 65)]);
  await ethers.provider.send("evm_mine");
}

main();
