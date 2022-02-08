require("dotenv").config();
require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.4"
      }
    ],
  },
  networks: {
    local: {
      url: "http://localhost:8545",
      timeout: 100000
    },
    hardhat: {
      forking: {
        url: process.env.ARCHIVE_NODE_URL,
        blockNumber: 14440000
      },
      chainId: 1337,
      accounts: {
        accountsBalance: "10000000000000000000000000000000"
      },
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 5000000000,
      timeout: 100000
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 5000000000,
      timeout: 100000
    },
  }
};
