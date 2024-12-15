require("@nomicfoundation/hardhat-toolbox");

require('dotenv').config({ path: __dirname + '/.env' })

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.22",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
    ],
  },
  networks: {
    bsc: {
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    bscTestnet: {
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },

  },
  sourcify: {
    enabled: true,
  },
  etherscan: {
    apiKey: {
      bsc: process.env.ABI_KEY,
      bscTestnet: process.env.ABI_KEY,
    },
  }
}
