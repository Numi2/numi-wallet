const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying MiningPool to Ethereum Mainnet...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Get the NumiCoin contract address (you'll need to provide this)
  const NUMICOIN_ADDRESS = process.env.NUMICOIN_ADDRESS;
  if (!NUMICOIN_ADDRESS) {
    throw new Error("Please set NUMICOIN_ADDRESS environment variable");
  }

  console.log("📝 Using NumiCoin address:", NUMICOIN_ADDRESS);

  // Deploy MiningPool contract
  const MiningPool = await ethers.getContractFactory("MiningPool");
  
  console.log("📝 Deploying MiningPool contract...");
  
  const miningPool = await MiningPool.deploy(
    NUMICOIN_ADDRESS, // NumiCoin contract address
    200, // Pool fee: 2% (98% to miners)
    deployer.address // Owner address
  );

  await miningPool.deployed();

  console.log("✅ MiningPool deployed to:", miningPool.address);
  console.log("📊 Contract Details:");
  console.log("   - NumiCoin Address:", await miningPool.numiCoin());
  console.log("   - Pool Fee:", await miningPool.poolFee(), "basis points (2%)");
  console.log("   - Owner:", await miningPool.owner());

  // Verify the deployment
  console.log("\n🔍 Verifying deployment...");
  const poolStats = await miningPool.getPoolStats();
  
  console.log("   - Total Shares:", ethers.utils.formatEther(poolStats.totalShares), "shares");
  console.log("   - Total Rewards:", ethers.utils.formatEther(poolStats.totalRewards), "NUMI");
  console.log("   - Active Miners:", poolStats.activeMiners.toString());

  // Save deployment info
  const deploymentInfo = {
    network: "ethereum-mainnet",
    contract: "MiningPool",
    address: miningPool.address,
    deployer: deployer.address,
    blockNumber: await miningPool.provider.getBlockNumber(),
    timestamp: Date.now(),
    parameters: {
      numiCoinAddress: NUMICOIN_ADDRESS,
      poolFee: "2% (200 basis points)",
      owner: deployer.address
    }
  };

  console.log("\n📄 Deployment Info:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  console.log("\n🎉 MiningPool successfully deployed to Ethereum Mainnet!");
  console.log("🔗 Contract Address:", miningPool.address);
  console.log("🌐 Etherscan URL: https://etherscan.io/address/" + miningPool.address);
  
  console.log("\n📋 Next Steps:");
  console.log("1. Verify contract on Etherscan");
  console.log("2. Update frontend with both contract addresses");
  console.log("3. Test pool mining functionality");
  console.log("4. Test staking and governance");
  console.log("5. Launch to community");

  return {
    numiCoinAddress: NUMICOIN_ADDRESS,
    miningPoolAddress: miningPool.address
  };
}

main()
  .then((addresses) => {
    console.log("\n✅ Deployment script completed successfully!");
    console.log("NumiCoin address:", addresses.numiCoinAddress);
    console.log("MiningPool address:", addresses.miningPoolAddress);
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }); 