const { ethers, upgrades } = require("hardhat");

async function tokenDeploy() {
  const Token = await ethers.getContractFactory("matchToken");
  const token = await Token.deploy("MATCH0", "m0");
  await token.waitForDeployment();
  console.log("Token deployed to:", token.target); //
}

// tokenDeploy();

async function upgradeDeploy() {
  // const [deployer] = await ethers.getSigners();
  // console.log("Deploying contracts with the account:", deployer.address);
  const erc20 = "0xffbc2aA0bf5B6f722a98Cc0563968134227Ca4a1";
  const protocol = "0x8048546982F7cF509a1A188B8A7eF265D1c2Ca1f";
  const st = 360;
  const et = 540;
  const Token = await ethers.getContractFactory("MatchP");
  const token = await upgrades.deployProxy(Token, [erc20, protocol, st, et], {
    initializer: "initialize",
  });
  await token.waitForDeployment();
  console.log("Token address:", token.target); //0x543f682BEd4458Ec024528b228052e5723D9531B
}

upgradeDeploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
