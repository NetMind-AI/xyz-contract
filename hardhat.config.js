require("@nomicfoundation/hardhat-toolbox");
// require("hardhat-deploy");
require("@openzeppelin/hardhat-upgrades");
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
      gasPrice: 1000000000,
      accounts: [process.env.PRIVATE_KEY],
    },
    bscTestnet: {
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    holesky: {
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    baseSepolia: {
      url: process.env.RPC_URL,
      chainId: 84532,
      accounts: [process.env.PRIVATE_KEY],
    },
    base: {
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
      holesky: process.env.ABI_KEY,
      baseSepolia: process.env.ABI_KEY,
      base: process.env.ABI_KEY,
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  }
}
