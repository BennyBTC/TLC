const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers.utils;

const routerAbi = require("./abi/IPancakeRouter02.json");
const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";

let owner, devAccount, marketingAccount, user1, user2;
let tlcToken, presale;

describe("TLC Token", function () {
  this.timeout(1000000);

  before(async function () {

    [ owner, devAccount, marketingAccount, user1, user2 ] = await ethers.getSigners();

    const TLCTokenFactory = await ethers.getContractFactory("TLCToken");
    tlcToken = await TLCTokenFactory.deploy(
      devAccount.address,
      marketingAccount.address,
      ethers.utils.parseEther("1"),
    );
    await tlcToken.deployed();

    const PreSaleFactory = await ethers.getContractFactory("PreSale");
    presale = await PreSaleFactory.deploy(
      ethers.utils.parseEther("0.001"),
      ethers.utils.parseEther("5"),
      tlcToken.address
    );
    await presale.deployed();

    await tlcToken.transfer(presale.address, parseEther("10000000")); // 10 mil to presale

    const routerContract = new ethers.Contract(routerAddress, routerAbi, owner);
    await tlcToken.approve(routerAddress, parseEther("1000000000"));
    // add liquidity 10,000,000 TLC & 10,000 BNB
    await routerContract.addLiquidityETH(
      tlcToken.address,
      parseEther("10000000"),
      parseEther("10000000"),
      parseEther("10000"),
      owner.address,
      parseEther("123456789"), // deadline
			{ value: parseEther("10000") },
    );
  });

  it("should allow owner to set initialize presale", async function () {
    await presale.addWhitelist([ user1.address ]);
    const isUser1Whitelist = await presale.whitelist(user1.address);
    expect(isUser1Whitelist).to.be.true;

    await tlcToken.transfer(presale.address, parseEther("1000000"));
  });

  it("should allow user1 to purchase token", async function () {
    const prevBalance = await tlcToken.balanceOf(user1.address);
    expect(prevBalance).to.equal(parseEther("0"));
    await user1.sendTransaction({
      value: parseEther("5"),
      to: presale.address,
    });
    const postBalance = await tlcToken.balanceOf(user1.address);
    expect(postBalance).to.equal(parseEther("5000"));
  });
});
