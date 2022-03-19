const { ethers } = require("hardhat");
const { abi } = require("../artifacts/contracts/HodlBank.sol/HodlBank.json");

async function main() {
  const hodlBankAddress = "0x6EB3FdA5449d5dbAC03C177383fda54d1fF34A8f";

  const [signer] = await ethers.provider.listAccounts();
  //const address = await signer.getAddress();
  const bank = await ethers.getContractAt(abi, hodlBankAddress);
  bank.connect(signer);
  const owner = await bank.getAllowedTokens();

  await bank.deployStrategy("test", [{ token: "0xc778417E063141139Fce010982780140Aa0cD5Ab", ratio: 100 }], (30 * 24 * 3600));

  const deployed = await bank.getStrategies();
  console.log(deployed);

  console.log(owner);
}

main();
