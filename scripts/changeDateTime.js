const { ethers } = require("hardhat");
const { abi } = require("../artifacts/contracts/HodlBank.sol/HodlBank.json");

async function main() {
  const [signer] = await ethers.provider.listAccounts();

  await ethers.provider.send("evm_increaseTime", [-(3600 * 24 * 65)]);
  await ethers.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

/*
  //const address = await signer.getAddress();
  const bank = await ethers.getContractAt(abi, hodlBankAddress);
  bank.connect(signer);
  const owner = await bank.getAllowedTokens();

  await bank.deployStrategy("test", [{ token: "0xc778417E063141139Fce010982780140Aa0cD5Ab", ratio: 100 }], (30 * 24 * 3600));

  const deployed = await bank.getStrategies();
  console.log(deployed);

  console.log(owner);*/
}

main();
