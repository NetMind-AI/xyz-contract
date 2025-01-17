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
    let ProxyAdmin = await deploy('ProxyAdmin',0,'ProxyAdmin')

    let FeeReceive = await deploy('FeeReceive',0,'FeeReceive')
    let FeeReceiveProxy = await deploy('FeeReceiveProxy',0,'TransparentUpgradeableProxy', FeeReceive.target, ProxyAdmin.target, "0x")
    FeeReceive = await getContract(0,'FeeReceive', FeeReceiveProxy.target.toString())
    let tx = await FeeReceive.initialize();
    await tx.wait(3);

    let AgentVault = await deploy('AgentVault',0,'AgentVault', deployer.address, {file:"AgentVault"})
    let AgentFactory = await deploy('AgentFactory',0,'AgentFactory')
    let AgentFactoryProxy = await deploy('AgentFactoryProxy',0,'TransparentUpgradeableProxy', AgentFactory.target, ProxyAdmin.target, "0x")
    AgentFactory = await getContract(0,'AgentFactory', AgentFactoryProxy.target.toString())
    let AgentNFT = await deploy('AgentNFT',0,'NetmindAgentNFT', AgentFactory.target, {file:"AgentNFT"})

    let AgentToken = await deploy('AgentToken',0,'AgentToken')
    let FFactory = await deploy('FFactory',0,'FFactory')
    let FFactoryProxy = await deploy('FFactoryProxy',0,'TransparentUpgradeableProxy', FFactory.target, ProxyAdmin.target, "0x")
    FFactory = await getContract(0,'FFactory', FFactoryProxy.target.toString())
    tx = await FFactory.initialize(FeeReceive.target, process.env.FACTORY_BUY_TAX, process.env.FACTORY_SELL_TAX);
    await tx.wait(3);
    tx = await FFactory.grantRole(await FFactory.ADMIN_ROLE(), deployer.address);
    await tx.wait(3);

    let FRouter = await deploy('FRouter',0,'FRouter')
    let FRouterProxy = await deploy('FRouterProxy',0,'TransparentUpgradeableProxy', FRouter.target, ProxyAdmin.target, "0x")
    FRouter = await getContract(0,'FRouter', FRouterProxy.target.toString())
    tx = await FRouter.initialize(FFactory.target, process.env.VAULT_TOKEN)
    await tx.wait(3);
    tx = await FFactory.setRouter(FRouter.target);
    await tx.wait(3);

    let Governor = await deploy('Governor',0,'Governor')
    let GovernorToken = await deploy('GovernorToken',0,'GovernorToken')
    let TimelockController = await deploy('TimelockController',0,'TimelockController')

    let Bonding = await deploy('Bonding',0,'Bonding')
    let BondingProxy = await deploy('BondingProxy',0,'TransparentUpgradeableProxy', Bonding.target, ProxyAdmin.target, "0x")
    Bonding = await getContract(0,'Bonding', BondingProxy.target.toString())
    tx = await AgentFactory.initialize(deployer.address, Bonding.target, AgentNFT.target, AgentVault.target);
    await tx.wait(3);
    tx = await Bonding.initialize(
        FFactory.target,
        FRouter.target,
        FeeReceive.target,
        process.env.FEE,
        ethers.parseEther(process.env.INITIAL_SUPPLY.toString()),
        process.env.ASSET_RATE,
        AgentFactory.target,
        process.env.UNISWAP_ROUTER,
        process.env.TOKEN_ADMIN,
        AgentToken.target,
        GovernorToken.target,
        Governor.target,
        TimelockController.target,
        process.env.DEFAULT_DELEGATEE,
        process.env.GRAD_THRESHOLD
    )
    await tx.wait(3);
    tx = await Bonding.setTokenParm(
      process.env.SWAP_THRESHOLD,
      process.env.BUY_TAX,
      process.env.SELL_TAX,
      FeeReceive.target,
    );
    await tx.wait(3);
    tx = await FFactory.grantRole(await FFactory.CREATOR_ROLE(), Bonding.target);
    await tx.wait(3);
    tx = await FRouter.grantRole(await FRouter.EXECUTOR_ROLE(), Bonding.target);
    await tx.wait(3);

    tx = await Bonding.setGovernorImpl(GovernorToken.target.toString(), Governor.target.toString(), TimelockController.target.toString())
    await tx.wait(3);
    tx = await Bonding.setGovernorParm(
        process.env.TIMELOCK_DELAY,
        process.env.VOTING_DELAY,
        process.env.VOTING_PERIOD,
        ethers.parseEther(process.env.PROPOSAL_THRESHOLD),
        process.env.QUORUM_NUMERATOR
    )
    await tx.wait(3);
    console.log(await Bonding.getTokenParm())

}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    saveAddr(addrList)
    console.error(error);
    process.exitCode = 1;
});
