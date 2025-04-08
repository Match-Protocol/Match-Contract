//  升级合约
const { ethers, upgrades } = require("hardhat");
async function main() {
  const match = await ethers.getContractFactory("MatchP");
  console.log("Upgrading ...");
  //  upgrades包中的 upgradeProxy是升级的关键,第一个参数是要升级的合约地址,第二个参数是新的合约工厂实例
  await upgrades.upgradeProxy(
    "0xf2267a52A11875b5e7D9089807c954B081D38618",
    match
  );
  console.log(" upgraded success :");
}

main();
