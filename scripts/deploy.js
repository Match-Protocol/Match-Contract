const { ethers, upgrades } = require("hardhat");

async function tokenDeploy() {
  const Token = await ethers.getContractFactory("matchToken");
  const token = await Token.deploy("M", "m");
  await token.waitForDeployment();
  console.log("Token deployed to:", token.target); // 0xAb5CdC0BA27716eae9E61E0B5a1fABaa2B01E7d6
}

// tokenDeploy();

async function upgradeDeploy() {
  // const [deployer] = await ethers.getSigners();
  // console.log("Deploying contracts with the account:", deployer.address);
  const erc20 = "0xAb5CdC0BA27716eae9E61E0B5a1fABaa2B01E7d6";
  const protocol = "0x8048546982F7cF509a1A188B8A7eF265D1c2Ca1f";
  const st = 360;
  const et = 540;
  const Token = await ethers.getContractFactory("MatchP");
  const token = await upgrades.deployProxy(Token, [erc20, protocol, st, et], {
    initializer: "initialize",
  });
  await token.waitForDeployment();
  console.log("Token address:", token.target); //0x5525cc1EB3A7F0c2D6d5869E50f471dF0Ce46160
}

upgradeDeploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
