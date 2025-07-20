const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("🚀 NumiCoin Full Deployment to Ethereum Mainnet");
  console.log("=" .repeat(60));

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");

  // Check if we have enough ETH
  const balance = await deployer.getBalance();
  const requiredBalance = ethers.utils.parseEther("3"); // 3 ETH minimum
  if (balance.lt(requiredBalance)) {
    throw new Error(`Insufficient balance. Need at least 3 ETH, have ${ethers.utils.formatEther(balance)} ETH`);
  }

  console.log("\n✅ Sufficient balance for deployment");

  // Step 1: Deploy NumiCoin Contract
  console.log("\n📝 Step 1: Deploying NumiCoin Contract...");
  const NumiCoin = await ethers.getContractFactory("NumiCoin");
  
  const numiCoin = await NumiCoin.deploy(
    2, // Initial difficulty (easy mining for people's coin)
    ethers.utils.parseEther("0.005"), // Block reward: 0.005 NUMI
    600, // Target block time: 10 minutes
    ethers.utils.parseEther("1000"), // Governance threshold: 1000 NUMI staked
    deployer.address // Owner address
  );

  await numiCoin.deployed();
  console.log("✅ NumiCoin deployed to:", numiCoin.address);

  // Step 2: Deploy MiningPool Contract
  console.log("\n📝 Step 2: Deploying MiningPool Contract...");
  const MiningPool = await ethers.getContractFactory("MiningPool");
  
  const miningPool = await MiningPool.deploy(
    numiCoin.address, // NumiCoin contract address
    200, // Pool fee: 2% (98% to miners)
    deployer.address // Owner address
  );

  await miningPool.deployed();
  console.log("✅ MiningPool deployed to:", miningPool.address);

  // Step 3: Verify deployments
  console.log("\n🔍 Step 3: Verifying deployments...");
  
  const numiCoinStats = await numiCoin.getMiningStats();
  const poolStats = await miningPool.getPoolStats();

  console.log("📊 NumiCoin Contract Details:");
  console.log("   - Initial Difficulty:", await numiCoin.difficulty());
  console.log("   - Block Reward:", ethers.utils.formatEther(await numiCoin.blockReward()), "NUMI");
  console.log("   - Target Block Time:", await numiCoin.targetMineTime(), "seconds");
  console.log("   - Governance Threshold:", ethers.utils.formatEther(await numiCoin.governanceThreshold()), "NUMI");
  console.log("   - Current Block:", numiCoinStats.currentBlock.toString());
  console.log("   - Total Supply:", ethers.utils.formatEther(await numiCoin.totalSupply()), "NUMI");

  console.log("\n📊 MiningPool Contract Details:");
  console.log("   - NumiCoin Address:", await miningPool.numiCoin());
  console.log("   - Pool Fee:", await miningPool.poolFee(), "basis points (2%)");
  console.log("   - Total Shares:", ethers.utils.formatEther(poolStats.totalShares), "shares");
  console.log("   - Active Miners:", poolStats.activeMiners.toString());

  // Step 4: Save deployment info
  console.log("\n📄 Step 4: Saving deployment information...");
  
  const deploymentInfo = {
    network: "ethereum-mainnet",
    timestamp: Date.now(),
    deployer: deployer.address,
    contracts: {
      numiCoin: {
        name: "NumiCoin",
        address: numiCoin.address,
        blockNumber: await numiCoin.provider.getBlockNumber(),
        parameters: {
          initialDifficulty: 2,
          blockReward: "0.005 NUMI",
          targetBlockTime: "600 seconds (10 minutes)",
          governanceThreshold: "1000 NUMI",
          owner: deployer.address
        }
      },
      miningPool: {
        name: "MiningPool",
        address: miningPool.address,
        blockNumber: await miningPool.provider.getBlockNumber(),
        parameters: {
          numiCoinAddress: numiCoin.address,
          poolFee: "2% (200 basis points)",
          owner: deployer.address
        }
      }
    },
    etherscan: {
      numiCoin: `https://etherscan.io/address/${numiCoin.address}`,
      miningPool: `https://etherscan.io/address/${miningPool.address}`
    }
  };

  // Save to file
  fs.writeFileSync("deployment-info.json", JSON.stringify(deploymentInfo, null, 2));
  console.log("✅ Deployment info saved to deployment-info.json");

  // Step 5: Generate environment variables
  console.log("\n🔧 Step 5: Generating environment variables...");
  
  const envVars = `# NumiCoin Production Environment Variables
# Generated on ${new Date().toISOString()}

# Contract Addresses
NEXT_PUBLIC_NUMICOIN_ADDRESS=${numiCoin.address}
NEXT_PUBLIC_MINING_POOL_ADDRESS=${miningPool.address}

# Network Configuration
NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_EXPLORER_URL=https://etherscan.io

# RPC URL (update with your Infura/Alchemy key)
NEXT_PUBLIC_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID

# Optional: Alternative RPC providers
# NEXT_PUBLIC_ALCHEMY_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_ALCHEMY_KEY
# NEXT_PUBLIC_QUICKNODE_RPC_URL=https://your-quicknode-endpoint.com
`;

  fs.writeFileSync("production.env", envVars);
  console.log("✅ Environment variables saved to production.env");

  // Step 6: Display next steps
  console.log("\n🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
  console.log("=" .repeat(60));
  
  console.log("\n📋 Next Steps:");
  console.log("1. Verify contracts on Etherscan:");
  console.log(`   NumiCoin: https://etherscan.io/address/${numiCoin.address}#code`);
  console.log(`   MiningPool: https://etherscan.io/address/${miningPool.address}#code`);
  
  console.log("\n2. Update your Vercel environment variables with the contents of production.env");
  
  console.log("\n3. Deploy the updated frontend:");
  console.log("   vercel --prod");
  
  console.log("\n4. Test the mining functionality:");
  console.log("   - Visit your deployed app");
  console.log("   - Create or import a wallet");
  console.log("   - Start mining real NUMI tokens");
  
  console.log("\n5. Monitor the contracts:");
  console.log("   - Check Etherscan for activity");
  console.log("   - Monitor gas prices and difficulty");
  console.log("   - Gather user feedback");

  console.log("\n🌟 NumiCoin - The People's Coin is now live on Ethereum mainnet!");
  console.log("🔗 Contract Addresses:");
  console.log(`   NumiCoin: ${numiCoin.address}`);
  console.log(`   MiningPool: ${miningPool.address}`);

  return {
    numiCoinAddress: numiCoin.address,
    miningPoolAddress: miningPool.address
  };
}

main()
  .then((addresses) => {
    console.log("\n✅ Full deployment completed successfully!");
    console.log("Contract addresses:", addresses);
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }); 