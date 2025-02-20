const { ethers, upgrades } = require('hardhat');

/*
         npx hardhat run ./verfyUpgrade.js
*/

async function main() {
    const beforeUpgrade = await ethers.getContractFactory('Bonding');
    const afterUpgrade = await ethers.getContractFactory('BondingV2');
    let result = await upgrades.validateUpgrade(beforeUpgrade, afterUpgrade);
    console.log(result)
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
