const { ethers } = require("hardhat");
const { parseEther } = ethers.utils;

const routerAbi = require("../test/abi/IPancakeRouter02.json");
const factoryAbi = require("../test/abi/IPancakeFactory.json");
const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const factoryAddress = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
const wbnbAddress = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

async function main() {
    [ owner ] = await ethers.getSigners();

    const ownerAddress = process.env.OWNER_ADDRESS || owner.address;
    console.log(`deployer address - ${owner.address}`);
    console.log(`owner address - ${ownerAddress}`);

    const TLCTokenFactory = await ethers.getContractFactory("TLCToken");
    tlcToken = await TLCTokenFactory.deploy(
      ownerAddress,
      ownerAddress,
      ownerAddress,
      ethers.utils.parseEther("100")
    );
    await tlcToken.deployed();
    console.log(`Deployed token at - ${tlcToken.address}`);

    const PreSaleFactory = await ethers.getContractFactory("PreSale");
    presale = await PreSaleFactory.deploy(
      ethers.utils.parseEther("0.001"),
      tlcToken.address
    );
    await presale.deployed();
    console.log(`Deployed presale at - ${presale.address}`);

    const PreSaleAuctionFactory = await ethers.getContractFactory("PreSaleAuction");
    presaleAuction = await PreSaleAuctionFactory.deploy(
      tlcToken.address
    );
    await presaleAuction.deployed();
    console.log(`Deployed presale auction at - ${presaleAuction.address}`);

    // await (await tlcToken.transfer(presaleAuction.address, parseEther("5000000"))).wait(); // 5 mil to presale auction

    // await (await tlcToken.transfer(presale.address, parseEther("10000000"))).wait(); // 10 mil to presale

    // routerContract = new ethers.Contract(routerAddress, routerAbi, ethers.provider);
    // await (await tlcToken.approve(routerAddress, parseEther("1000000000"))).wait();
    // add liquidity 10,000,000 TLC & 10,000 BNB
    // await (await routerContract.connect(owner).addLiquidityETH(
    //   tlcToken.address,
    //   parseEther("1"),
    //   parseEther("1"),
    //   parseEther("0.01"),
    //   owner.address,
    //   parseEther("123456789"), // deadline
		// 	{ value: parseEther("0.01") },
    // )).wait();
    // console.log("added liquidity");
    // await delay(20000);

    // const factoryContract = new ethers.Contract(factoryAddress, factoryAbi, ethers.provider);
    // const pair = await factoryContract.getPair(tlcToken.address, wbnbAddress);
    // console.log(`PCS pair = ${pair}`);
    // await tlcToken.setTransferToFee(pair, 400);
    // console.log("Set transfer to fee for sells");
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
