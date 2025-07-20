const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Setting up NumiCoin Ecosystem...\n");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📋 Deployer:", deployer.address);
  console.log("💰 Balance:", ethers.formatEther(await deployer.getBalance()), "ETH\n");

  // Check if we have enough balance
  const balance = await deployer.getBalance();
  if (balance < ethers.parseEther("0.01")) {
    throw new Error("Insufficient balance for deployment. Need at least 0.01 ETH");
  }

  try {
    // Step 1: Deploy NumiCoin Contract
    console.log("📦 Step 1: Deploying NumiCoin Contract...");
    const NumiCoin = await ethers.getContractFactory("NumiCoin");
    const numiCoin = await NumiCoin.deploy();
    await numiCoin.waitForDeployment();
    const numiCoinAddress = await numiCoin.getAddress();
    console.log("✅ NumiCoin deployed to:", numiCoinAddress);

    // Step 2: Deploy MiningPool Contract
    console.log("\n🏊 Step 2: Deploying MiningPool Contract...");
    const MiningPool = await ethers.getContractFactory("MiningPool");
    const miningPool = await MiningPool.deploy(numiCoinAddress);
    await miningPool.waitForDeployment();
    const miningPoolAddress = await miningPool.getAddress();
    console.log("✅ MiningPool deployed to:", miningPoolAddress);

    // Step 3: Verify Contract Setup
    console.log("\n🔍 Step 3: Verifying Contract Setup...");
    
    // Check NumiCoin details
    const name = await numiCoin.name();
    const symbol = await numiCoin.symbol();
    const decimals = await numiCoin.decimals();
    console.log(`📝 Token: ${name} (${symbol}) - ${decimals} decimals`);

    // Check initial mining stats
    const miningStats = await numiCoin.getMiningStats();
    console.log("⛏️ Initial Mining Stats:");
    console.log(`   Current Block: ${miningStats[0]}`);
    console.log(`   Difficulty: ${miningStats[1]}`);
    console.log(`   Block Reward: ${ethers.formatEther(miningStats[2])} NUMI`);
    console.log(`   Target Mine Time: ${miningStats[4]} seconds`);

    // Check pool stats
    const poolStats = await miningPool.getPoolStats();
    console.log("🏊 Initial Pool Stats:");
    console.log(`   Total Shares: ${ethers.formatEther(poolStats[0])} NUMI`);
    console.log(`   Total Rewards: ${ethers.formatEther(poolStats[1])} NUMI`);
    console.log(`   Active Miners: ${poolStats[4]}`);

    // Step 4: Generate Configuration Files
    console.log("\n📄 Step 4: Generating Configuration Files...");
    
    const deploymentInfo = {
      network: hre.network.name,
      chainId: hre.network.config.chainId,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: {
        numiCoin: numiCoinAddress,
        miningPool: miningPoolAddress
      },
      verification: {
        numiCoin: {
          address: numiCoinAddress,
          constructorArgs: []
        },
        miningPool: {
          address: miningPoolAddress,
          constructorArgs: [numiCoinAddress]
        }
      }
    };

    // Save deployment info
    const deploymentPath = path.join(__dirname, "..", "deployment.json");
    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
    console.log("✅ Deployment info saved to:", deploymentPath);

    // Generate environment file
    const envContent = `# NumiCoin Environment Configuration
# Generated on ${new Date().toISOString()}

# Contract Addresses
NEXT_PUBLIC_NUMICOIN_ADDRESS=${numiCoinAddress}
NEXT_PUBLIC_MINING_POOL_ADDRESS=${miningPoolAddress}

# Network Configuration
NEXT_PUBLIC_NETWORK_NAME=${hre.network.name}
NEXT_PUBLIC_CHAIN_ID=${hre.network.config.chainId}

# RPC URLs (update with your preferred providers)
NEXT_PUBLIC_RPC_URL=${hre.network.config.url || "http://localhost:8545"}

# Optional: Etherscan API Key for contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Optional: For mainnet deployment
# PRIVATE_KEY=your_private_key_here
`;

    const envPath = path.join(__dirname, "..", ".env.local");
    fs.writeFileSync(envPath, envContent);
    console.log("✅ Environment file generated:", envPath);

    // Generate frontend configuration
    const frontendConfig = {
      contracts: {
        numiCoin: numiCoinAddress,
        miningPool: miningPoolAddress
      },
      network: {
        name: hre.network.name,
        chainId: hre.network.config.chainId,
        rpcUrl: hre.network.config.url || "http://localhost:8545"
      },
      mining: {
        initialDifficulty: 4,
        blockReward: "100",
        targetMineTime: 600
      }
    };

    const configPath = path.join(__dirname, "..", "frontend-config.json");
    fs.writeFileSync(configPath, JSON.stringify(frontendConfig, null, 2));
    console.log("✅ Frontend config generated:", configPath);

    // Step 5: Display Next Steps
    console.log("\n🎉 Ecosystem Setup Complete!");
    console.log("\n📋 Contract Addresses:");
    console.log("NumiCoin:", numiCoinAddress);
    console.log("MiningPool:", miningPoolAddress);
    console.log("Deployer:", deployer.address);

    console.log("\n📖 Next Steps:");
    console.log("1. Copy the environment variables to your frontend .env.local file");
    console.log("2. Update your frontend code to use the new contract addresses");
    console.log("3. Test the mining functionality on the deployed contracts");
    console.log("4. Verify contracts on block explorer (if on testnet/mainnet)");
    console.log("5. Deploy to mainnet when ready");

    if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
      console.log("\n🔍 Contract Verification Commands:");
      console.log(`npx hardhat verify --network ${hre.network.name} ${numiCoinAddress}`);
      console.log(`npx hardhat verify --network ${hre.network.name} ${miningPoolAddress} "${numiCoinAddress}"`);
    }

    console.log("\n💡 Testing Commands:");
    console.log("npm test");
    console.log("npm run coverage");

    console.log("\n🚀 Ready to mine NumiCoin!");

  } catch (error) {
    console.error("❌ Setup failed:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Setup failed:", error);
    process.exit(1);
  }); 