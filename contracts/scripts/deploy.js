const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying NumiCoin ecosystem...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy NumiCoin contract
  console.log("\n📦 Deploying NumiCoin contract...");
  const NumiCoin = await ethers.getContractFactory("NumiCoin");
  const numiCoin = await NumiCoin.deploy();
  await numiCoin.deployed();
  console.log("NumiCoin deployed to:", numiCoin.address);

  // Deploy MiningPool contract
  console.log("\n🏊 Deploying MiningPool contract...");
  const MiningPool = await ethers.getContractFactory("MiningPool");
  const miningPool = await MiningPool.deploy(numiCoin.address);
  await miningPool.deployed();
  console.log("MiningPool deployed to:", miningPool.address);

  // Verify contracts are working
  console.log("\n🔍 Verifying contracts...");
  
  // Check NumiCoin details
  const name = await numiCoin.name();
  const symbol = await numiCoin.symbol();
  const decimals = await numiCoin.decimals();
  console.log(`NumiCoin: ${name} (${symbol}) - ${decimals} decimals`);

  // Check mining stats
  const miningStats = await numiCoin.getMiningStats();
  console.log("Initial mining stats:", {
    currentBlock: miningStats._currentBlock.toString(),
    difficulty: miningStats._difficulty.toString(),
    blockReward: ethers.utils.formatEther(miningStats._blockReward),
    targetMineTime: miningStats._targetMineTime.toString()
  });

  // Check pool stats
  const poolStats = await miningPool.getPoolStats();
  console.log("Initial pool stats:", {
    totalShares: ethers.utils.formatEther(poolStats.totalShares),
    totalRewards: ethers.utils.formatEther(poolStats.totalRewards),
    activeMiners: poolStats.activeMiners.toString()
  });

  console.log("\n✅ Deployment completed successfully!");
  console.log("\n📋 Contract Addresses:");
  console.log("NumiCoin:", numiCoin.address);
  console.log("MiningPool:", miningPool.address);
  console.log("Deployer:", deployer.address);

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    deployer: deployer.address,
    contracts: {
      numiCoin: numiCoin.address,
      miningPool: miningPool.address
    },
    timestamp: new Date().toISOString()
  };

  console.log("\n💾 Deployment info saved to deployment.json");
  require('fs').writeFileSync(
    'deployment.json', 
    JSON.stringify(deploymentInfo, null, 2)
  );

  // Instructions for next steps
  console.log("\n📖 Next steps:");
  console.log("1. Update your frontend with the contract addresses");
  console.log("2. Set up environment variables:");
  console.log(`   NEXT_PUBLIC_NUMICOIN_ADDRESS=${numiCoin.address}`);
  console.log(`   NEXT_PUBLIC_MINING_POOL_ADDRESS=${miningPool.address}`);
  console.log("3. Test mining functionality");
  console.log("4. Deploy to mainnet when ready");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }); 