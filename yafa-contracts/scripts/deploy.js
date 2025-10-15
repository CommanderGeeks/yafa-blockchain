const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying YAFA Token to Yafa L2...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);

  // Check balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "ETH\n");

  // Deploy YAFA Token
  console.log("🪙 Deploying YafaToken...");
  const YafaToken = await hre.ethers.getContractFactory("YafaToken");
  const yafaToken = await YafaToken.deploy();
  
  await yafaToken.waitForDeployment();
  const tokenAddress = await yafaToken.getAddress();
  
  console.log("✅ YafaToken deployed to:", tokenAddress);
  
  // Get token info
  const name = await yafaToken.name();
  const symbol = await yafaToken.symbol();
  const totalSupply = await yafaToken.totalSupply();
  const decimals = await yafaToken.decimals();
  
  console.log("\n🎉 Token Details:");
  console.log("   Name:", name);
  console.log("   Symbol:", symbol);
  console.log("   Total Supply:", hre.ethers.formatEther(totalSupply), symbol);
  console.log("   Decimals:", decimals);
  console.log("   Owner:", deployer.address);
  
  console.log("\n💾 Save this address to add to MetaMask:", tokenAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
