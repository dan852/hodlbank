const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HodlBank", function () {
  let hodlBank, signer;

  const allowedTokens = [
    "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  ];

  before("deploy contract first", async function () {
    const HodlBank = await ethers.getContractFactory("HodlBank");
    hodlBank = await HodlBank.deploy(allowedTokens);
    await hodlBank.deployed();
    [signer] = await ethers.provider.listAccounts();

    const result = await hodlBank.getAllowedTokens();
    console.log(result);
  });

  it("should only allow specific tokens", async function () {
    expect(await hodlBank.allowedTokens(0)).equals(allowedTokens[0]);
    expect(await hodlBank.allowedTokens(1)).equals(allowedTokens[1]);
    expect(await hodlBank.allowedTokens(2)).equals(allowedTokens[2]);
  });

  it("it should set the owner to be the deployer of the contract", async function () {
    expect(await hodlBank.owner()).equals(signer);
  });

  it("test percentage calculation 1 ETH", async function () {
    expect(
      await hodlBank.mulDiv(ethers.utils.parseEther("1.0"), 50, 100)
    ).equals(ethers.utils.parseEther("0.5"));
  });

  it("test percentage calculation 100 ETH", async function () {
    expect(
      await hodlBank.mulDiv(ethers.utils.parseEther("100.0"), 50, 100)
    ).equals(ethers.utils.parseEther("50.0"));
  });

  it("test percentage calculation 0 ETH", async function () {
    expect(
      await hodlBank.mulDiv(ethers.utils.parseEther("0.0"), 50, 100)
    ).equals(ethers.utils.parseEther("0.0"));
  });

  it("test percentage calculation 1 ETH 100%", async function () {
    expect(
      await hodlBank.mulDiv(ethers.utils.parseEther("1.0"), 100, 100)
    ).equals(ethers.utils.parseEther("1.0"));
  });

  //it("deploy a strategy", async function () {
  // const strategy = await hodlBank.deployStrategy("test", [{ token: "0x6B175474E89094C44Da98b954EedeAC495271d0F", ratio: 100 }], (7 * 24 * 60 * 60));
  //  console.log(strategy);
  //});
});
