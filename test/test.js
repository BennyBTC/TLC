const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers.utils;

const routerAbi = require("./abi/IPancakeRouter02.json");
const factoryAbi = require("./abi/IPancakeFactory.json");
const erc20Abi = require("./abi/IERC20.json");
const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const factoryAddress = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
const wbnbAddress = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

let owner, devAccount, marketingAccount, user1, user2, user3;
let tlcToken, wbnbToken, presale, presaleAuction, routerContract;
let priceCliffs;

describe("TLC Token", function () {
  this.timeout(1000000);

  before(async function () {

    [ owner, devAccount, marketingAccount, user1, user2, user3 ] = await ethers.getSigners();

    wbnbToken = new ethers.Contract(wbnbAddress, erc20Abi, ethers.provider);

    const TLCTokenFactory = await ethers.getContractFactory("TLCToken");
    tlcToken = await TLCTokenFactory.deploy(
      owner.address,
      devAccount.address,
      marketingAccount.address,
      ethers.utils.parseEther("100"),
    );
    await tlcToken.deployed();

    const PreSaleFactory = await ethers.getContractFactory("PreSale");
    presale = await PreSaleFactory.deploy(
      ethers.utils.parseEther("0.001"),
      tlcToken.address
    );
    await presale.deployed();
    await tlcToken.transfer(presale.address, parseEther("10000000")); // 10 mil to presale

    const PreSaleAuctionFactory = await ethers.getContractFactory("PreSaleAuction");
    presaleAuction = await PreSaleAuctionFactory.deploy(
      tlcToken.address
    );
    await presaleAuction.deployed();
    await tlcToken.transfer(presaleAuction.address, parseEther("5000000")); // 5 mil to presale auction
    // priceCliffs = await presaleAuction.priceCliffs();

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
    await tlcToken.connect(user1).approve(routerAddress, parseEther("10000000000000"));
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

  it("should allow user1 to sell tokens without triggering sell", async function () {
    const prevBalance = await tlcToken.balanceOf(user1.address);
    expect(prevBalance).to.equal(parseEther("5000"));

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

  it("should allow user1 to sell tokens triggering sell", async function () {
    const prevDevBnbBalance = await wbnbToken.balanceOf(devAccount.address);
    const prevMarketingBnbBalance = await wbnbToken.balanceOf(marketingAccount.address);
    await routerContract.connect(user1).swapExactTokensForETHSupportingFeeOnTransferTokens(
      parseEther("1500"), // 
      parseEther("0"),
      [tlcToken.address, wbnbAddress],
      user1.address,
      parseEther("123456789") // deadline
    );
    await routerContract.connect(user1).swapExactTokensForETHSupportingFeeOnTransferTokens(
      parseEther("500"), // 
      parseEther("0"),
      [tlcToken.address, wbnbAddress],
      user1.address,
      parseEther("123456789") // deadline
    );
    const tokenFeeBalance = await tlcToken.balanceOf(tlcToken.address);
    expect(tokenFeeBalance).to.equal(parseEther("20"));
    const postDevBnbBalance = await wbnbToken.balanceOf(devAccount.address);
    const postMarketingBnbBalance = await wbnbToken.balanceOf(marketingAccount.address);
    expect(postDevBnbBalance.sub(prevDevBnbBalance).gt(0)).to.be.true;
    expect(postMarketingBnbBalance.sub(prevMarketingBnbBalance).gt(0)).to.be.true;
  });

  it("should allow users to purchase from presale auction at initial price", async function () {
    const prevBalance = await tlcToken.balanceOf(user2.address);
    expect(prevBalance).to.equal(parseEther("0"));
    const amount = parseEther("55");
    const expectedReturn = await presaleAuction.getExpectedReturn(amount);
    expect(expectedReturn).to.equal(parseEther("500000"));
    await user2.sendTransaction({ to: presaleAuction.address, value: amount });
    const postBalance = await tlcToken.balanceOf(user2.address);
    expect(postBalance).to.equal(expectedReturn);
  });

  it("should allow users to purchase from presale auction at two prices", async function () {
    const prevBalance = await tlcToken.balanceOf(user3.address);
    expect(prevBalance).to.equal(parseEther("0"));
    // currently 500,000/1,000,000 sold. 55 bnb for 1,000,000 and extra 32 for 200,000
    const amount = parseEther("87");
    const expectedReturn = await presaleAuction.getExpectedReturn(amount);
    expect(expectedReturn).to.equal(parseEther("700000"));
    await user3.sendTransaction({ to: presaleAuction.address, value: amount });
    const postBalance = await tlcToken.balanceOf(user3.address);
    expect(postBalance).to.equal(expectedReturn);
  });

});
