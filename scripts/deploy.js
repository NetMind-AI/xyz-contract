require('dotenv').config({ path: __dirname + '/.env' })
const web3 = require('web3')
let { addrList,getSingerAddr,getABI,getContract,getContractByABI,contractDeploy,executeContract,getStorageAt,getProxyslot,encodeFunction,sendTransaction,deploy,saveAddr,createFile,logTx,addrListAddObject } = require('./lib')
let { ethers, upgrades } = require("hardhat") ;
const fs = require("fs");
const hre = require("hardhat");
let configjson;
/*

*/

async function main() {
  await createFile()
  var data=fs.readFileSync('./config/config.json','utf-8');
  configjson = JSON.parse(data.toString());
  await exec()
  saveAddr(addrList)
}

async function exec() {

  let deployer =await getSingerAddr(0);
  let AgentToken = await deploy('AgentToken',0,'AgentToken')
  let FFactory = await deploy('FFactory',0,'FFactory')
  let FFactoryProxy = await deploy('FFactoryProxy',0,'FFactoryProxy', FFactory.target)
  FFactory = await getContract(0,'FFactory', FFactoryProxy.target.toString())
  tx = await FFactory.initialize(process.env.TAX_VAULT, process.env.FACTORY_BUY_TAX, process.env.FACTORY_SELL_TAX);
  await tx.wait(3);

  let ADMIN_ROLE = await FFactory.ADMIN_ROLE()
  await FFactory.grantRole(ADMIN_ROLE, deployer.address);

  let FRouter = await deploy('FRouter',0,'FRouter')
  let FRouterProxy = await deploy('FRouterProxy',0,'FRouterProxy', FRouter.target)
  FRouter = await getContract(0,'FRouter', FRouterProxy.target.toString())
  tx = await FRouter.initialize(FFactory.target, process.env.VAULT_TOKEN)
  await tx.wait(3);
  await FFactory.setRouter(FRouter.target);

  let Bonding = await deploy('Bonding',0,'Bonding')
  let BondingProxy = await deploy('BondingProxy',0,'BondingProxy', Bonding.target)
  Bonding = await getContract(0,'Bonding', BondingProxy.target.toString())
  tx = await Bonding.initialize(
      FFactory.target,
      FRouter.target,
      process.env.FEE_TO,
      process.env.FEE,
      ethers.parseEther(process.env.INITIAL_SUPPLY.toString()),
      process.env.ASSET_RATE,
      process.env.AGENT_FACTORY,
      process.env.UNISWAP_ROUTER,
      process.env.TOKEN_ADMIN,
      AgentToken.target,
      process.env.GRAD_THRESHOLD
  )
  await tx.wait(3);
  await Bonding.setTokenParm(
    process.env.SWAP_THRESHOLD,
    process.env.BUY_TAX,
    process.env.SELL_TAX,
    process.env.TAX_RECIPIENT_ADDR,
  );
  await tx.wait(1);
  let CREATOR_ROLE = await FFactory.CREATOR_ROLE()
  await FFactory.grantRole(CREATOR_ROLE, Bonding.target);
  await tx.wait(1);
  let EXECUTOR_ROLE = await FRouter.EXECUTOR_ROLE()
  await FRouter.grantRole(EXECUTOR_ROLE, Bonding.target);
  await tx.wait(1);






}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  saveAddr(addrList)
  console.error(error);
  process.exitCode = 1;
});
