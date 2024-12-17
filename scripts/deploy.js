require('dotenv').config({ path: __dirname + '/.env' })
let { ethers, upgrades } = require("hardhat") ;
const fs = require("fs");

async function main() {
  try {
    const deployer = new ethers.Wallet(
        process.env.PRIVATE_KEY,
        ethers.provider
    );


    const AgentToken = await ethers.deployContract("AgentToken");
    await AgentToken.waitForDeployment();

    const FFactory = await ethers.getContractFactory("FFactory");
    const fFactory = await upgrades.deployProxy(
        FFactory,
        [process.env.TAX_VAULT, process.env.FACTORY_BUY_TAX, process.env.FACTORY_SELL_TAX],
        { initializer: 'initialize' });
    const fFactoryAddress = await fFactory.getAddress();
    console.log("FFactory deployed to:", fFactoryAddress);
    let ADMIN_ROLE = await fFactory.ADMIN_ROLE()
      console.log("ADMIN_ROLE:", ADMIN_ROLE);
    await fFactory.grantRole(ADMIN_ROLE, deployer.address);

    const FRouter = await ethers.getContractFactory("FRouter");
    const fRouter = await upgrades.deployProxy(
        FRouter,
        [fFactory.target, process.env.VAULT_TOKEN],
        { initializer: 'initialize' });
    const fRouterAddress = await fRouter.getAddress();
    console.log("fRouter deployed to:", fRouterAddress);
    await fFactory.setRouter(fRouter.target);

    const Bonding = await ethers.getContractFactory("Bonding");
    const bonding = await upgrades.deployProxy(
        Bonding,
        [
              fFactory.target,
              fRouter.target,
              process.env.FEE_TO,
              process.env.FEE,
              ethers.parseEther(process.env.INITIAL_SUPPLY.toString()),
              process.env.ASSET_RATE,
              process.env.AGENT_FACTORY,
              process.env.UNISWAP_ROUTER,
              process.env.TOKEN_ADMIN,
              AgentToken.target,
              process.env.GRAD_THRESHOLD
        ],
        { initializer: 'initialize' });
    const bondingAddress = await bonding.getAddress();
    console.log("bonding deployed to:", bondingAddress);
    await bonding.setTokenParm(
      process.env.SWAP_THRESHOLD,
      process.env.BUY_TAX,
      process.env.SELL_TAX,
      process.env.TAX_RECIPIENT_ADDR,
    );
    let CREATOR_ROLE = await fFactory.CREATOR_ROLE()
    await fFactory.grantRole(CREATOR_ROLE, bonding.target);
    let EXECUTOR_ROLE = await fRouter.EXECUTOR_ROLE()
    await fRouter.grantRole(EXECUTOR_ROLE, bonding.target);


    //deploy Agent instances
    const AgentNFT = await ethers.deployContract("AgentNFT", ethers.provider.address);
    await AgentNFT.waitForDeployment();

    const AgentVault = await ethers.deployContract("AgentVault", AgentNFT.target, ethers.provider.address);
    await AgentVault.waitForDeployment();
    
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    



  } catch (e) {
    console.error(e);
  }
}


// async function main() {
//   try {
//     await run("verify:verify", {
//       address: "0x06993D28FF838184cf98aa0aa16F227d40482156",
//       constructorArguments: [],
//     });
//   } catch (e) {
//     console.error(e);
//   }
// }


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
