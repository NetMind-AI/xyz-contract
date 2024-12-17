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
    await upgradeExec()
    saveAddr(addrList)
}

async function exec() {
    let deployer =await getSingerAddr(0);
    let ProxyAdmin = await deploy('ProxyAdmin',0,'ProxyAdmin')

    let AgentNFT = await deploy('AgentNFT',0,'NetmindAgentNFT', deployer.address, {file:"AgentNFT"})
    let AgentVault = await deploy('AgentVault',0,'AgentVault', AgentNFT.target, deployer.address)
    let AgentFactory = await deploy('AgentFactory',0,'AgentFactory')
    let AgentFactoryProxy = await deploy('AgentFactoryProxy',0,'TransparentUpgradeableProxy', AgentFactory.target, ProxyAdmin.target, "0x")
    AgentFactory = await getContract(0,'AgentFactory', AgentFactoryProxy.target.toString())

    let AgentToken = await deploy('AgentToken',0,'AgentToken')
    let FFactory = await deploy('FFactory',0,'FFactory')
    let FFactoryProxy = await deploy('FFactoryProxy',0,'TransparentUpgradeableProxy', FFactory.target, ProxyAdmin.target, "0x")
    FFactory = await getContract(0,'FFactory', FFactoryProxy.target.toString())
    tx = await FFactory.initialize(process.env.TAX_VAULT, process.env.FACTORY_BUY_TAX, process.env.FACTORY_SELL_TAX);
    await tx.wait();
    await FFactory.grantRole(await FFactory.ADMIN_ROLE(), deployer.address);

    let FRouter = await deploy('FRouter',0,'FRouter')
    let FRouterProxy = await deploy('FRouterProxy',0,'TransparentUpgradeableProxy', FRouter.target, ProxyAdmin.target, "0x")
    FRouter = await getContract(0,'FRouter', FRouterProxy.target.toString())
    tx = await FRouter.initialize(FFactory.target, process.env.VAULT_TOKEN)
    await tx.wait();
    await FFactory.setRouter(FRouter.target);

    let Bonding = await deploy('Bonding',0,'Bonding')
    let BondingProxy = await deploy('BondingProxy',0,'TransparentUpgradeableProxy', Bonding.target, ProxyAdmin.target, "0x")
    Bonding = await getContract(0,'Bonding', BondingProxy.target.toString())
    tx = await AgentFactory.initialize(deployer.address, Bonding.target, AgentNFT.target, AgentVault.target);
    await tx.wait();
    tx = await Bonding.initialize(
        FFactory.target,
        FRouter.target,
        process.env.FEE_TO,
        process.env.FEE,
        ethers.parseEther(process.env.INITIAL_SUPPLY.toString()),
        process.env.ASSET_RATE,
        AgentFactory.target,
        process.env.UNISWAP_ROUTER,
        process.env.TOKEN_ADMIN,
        AgentToken.target,
        process.env.GRAD_THRESHOLD
    )
    await tx.wait();
    tx = await Bonding.setTokenParm(
      process.env.SWAP_THRESHOLD,
      process.env.BUY_TAX,
      process.env.SELL_TAX,
      process.env.TAX_RECIPIENT_ADDR,
    );
    await tx.wait();
    tx = await FFactory.grantRole(await FFactory.CREATOR_ROLE(), Bonding.target);
    await tx.wait();
    tx = await FRouter.grantRole(await FRouter.EXECUTOR_ROLE(), Bonding.target);
    await tx.wait();
    console.log(await Bonding.getTokenParm())
}

async function upgradeExec() {
    let ProxyAdminAddr = "0xDD6C4c4966f4576FC5aC74b4A1Cf1096B3C30530";
    let ProxyAdmin = await getContract(0,'ProxyAdmin', ProxyAdminAddr)
    let AgentFactory = await deploy('AgentFactory',0,'AgentFactory')
    await ProxyAdmin.upgrade("0x00DE127db8b9E65Df5C0ca6931f001Cb6A0AFAD2", AgentFactory.target)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    saveAddr(addrList)
    console.error(error);
    process.exitCode = 1;
});
