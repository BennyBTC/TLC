const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers.utils;

const routerAbi = require("./abi/IPancakeRouter02.json");
const factoryAbi = require("./abi/IPancakeFactory.json");
const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const factoryAddress = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
const wbnbAddress = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

let owner, devAccount, marketingAccount, user1, user2;
let tlcToken, presale, routerContract;

describe("TLC Token", function () {
  this.timeout(1000000);

  before(async function () {

    [ owner, devAccount, marketingAccount, user1, user2 ] = await ethers.getSigners();

    const TLCTokenFactory = await ethers.getContractFactory("TLCToken");
    tlcToken = await TLCTokenFactory.deploy(
      devAccount.address,
      marketingAccount.address,
      ethers.utils.parseEther("100"),
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

    routerContract = new ethers.Contract(routerAddress, routerAbi, ethers.provider);
    await tlcToken.approve(routerAddress, parseEther("1000000000"));
    // add liquidity 10,000,000 TLC & 10,000 BNB
    await routerContract.connect(owner).addLiquidityETH(
      tlcToken.address,
      parseEther("10000000"),
      parseEther("10000000"),
      parseEther("10000"),
      owner.address,
      parseEther("123456789"), // deadline
			{ value: parseEther("10000") },
    );

    const factoryContract = new ethers.Contract(factoryAddress, factoryAbi, ethers.provider);
    const pair = await factoryContract.getPair(tlcToken.address, wbnbAddress);
    await tlcToken.setTransferToFee(pair, 400);
  });

  it("should allow owner to set initialize presale", async function () {
    await presale.addWhitelist([ user1.address ]);
    const isUser1Whitelist = await presale.whitelist(user1.address);
    expect(isUser1Whitelist).to.be.true;

    await tlcToken.transfer(presale.address, parseEther("1000000"));
  });

  it("should allow user1 to purchase token from presale", async function () {
    const prevBalance = await tlcToken.balanceOf(user1.address);
    expect(prevBalance).to.equal(parseEther("0"));
    await user1.sendTransaction({
      value: parseEther("5"),
      to: presale.address,
    });
    const postBalance = await tlcToken.balanceOf(user1.address);
    expect(postBalance).to.equal(parseEther("5000"));
  });

  it("should allow user1 to sell token without triggering sell", async function () {
    const prevBalance = await tlcToken.balanceOf(user1.address);
    expect(prevBalance).to.equal(parseEther("5000"));

    await tlcToken.connect(user1).approve(routerAddress, parseEther("10000000000000"));
    await routerContract.connect(user1).swapExactTokensForETHSupportingFeeOnTransferTokens(
      parseEther("1000"), // 
      parseEther("0"),
      [tlcToken.address, wbnbAddress],
      user1.address,
      parseEther("123456789") // deadline
    );
    const postBalance = await tlcToken.balanceOf(user1.address);
    expect(postBalance).to.equal(parseEther("4000"));
    const tokenFeeBalance = await tlcToken.balanceOf(tlcToken.address);
    expect(tokenFeeBalance).to.equal(parseEther("40"));
  });

});
