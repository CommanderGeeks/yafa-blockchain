require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: "../.env" });

const PRIVATE_KEY = process.env.PRIVATE_KEY;

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    yafaL2: {
      url: "http://localhost:8545",
      accounts: [PRIVATE_KEY],
      chainId: 42069,
      timeout: 60000
    }
  }
};
