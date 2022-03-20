const hre = require("hardhat");

async function main() {
  const HodlBank = await hre.ethers.getContractFactory("HodlBank");
  const hodl = await HodlBank.deploy([
    "0x01BE23585060835E02B77ef475b0Cc51aA1e0709",
    "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
    "0xc778417E063141139Fce010982780140Aa0cD5Ab",
    "0xddea378A6dDC8AfeC82C36E9b0078826bf9e68B6",
    "0xc7ad46e0b8a400bb3c915120d284aafba8fc4735",
    "0x45075E4BdB8025f4B5c71876399FE5F8C89a3c73",
  ]);

  await hodl.deployed();

  console.log("HodlBank deployed to:", hodl.address);

  const MAX_SUPPLY = 10000000;

  const HodlBankToken = await hre.ethers.getContractFactory("HodlBankToken");
  const hodlToken = await HodlBankToken.deploy(MAX_SUPPLY);

  console.log("HodlBank Token deployed to:", hodlToken.address);

  await hodlToken.transfer(hodl.address, MAX_SUPPLY);

  const balance = await hodlToken.balanceOf(hodl.address);
  console.log("HodlBank Contract Balance is", balance);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
