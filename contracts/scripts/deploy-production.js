const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 NumiCoin Production Deployment");
  console.log("================================\n");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📋 Deployer:", deployer.address);
  console.log("💰 Balance:", ethers.formatEther(await deployer.getBalance()), "ETH\n");

  // Pre-deployment checks
  console.log("🔍 Pre-deployment Checks:");
  
  // Check balance
  const balance = await deployer.getBalance();
  if (balance < ethers.parseEther("0.1")) {
    throw new Error("Insufficient balance for production deployment. Need at least 0.1 ETH");
  }
  console.log("✅ Sufficient balance");

  // Check network
  const network = hre.network.name;
  if (network === "hardhat" || network === "localhost") {
    throw new Error("Cannot deploy to local network in production mode");
  }
  console.log("✅ Network:", network);

  // Check environment variables
  if (!process.env.ETHERSCAN_API_KEY) {
    console.warn("⚠️  ETHERSCAN_API_KEY not set - contracts won't be verified");
  } else {
    console.log("✅ Etherscan API key configured");
  }

  console.log("\n📦 Starting Production Deployment...\n");

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

    // Step 4: Generate Production Configuration
    console.log("\n📄 Step 4: Generating Production Configuration...");
    
    const deploymentInfo = {
      network: network,
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
      },
      production: {
        deployed: true,
        verified: false,
        monitored: false
      }
    };

    // Save deployment info
    const deploymentPath = path.join(__dirname, "..", "deployment-production.json");
    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
    console.log("✅ Deployment info saved to:", deploymentPath);

    // Generate production environment file
    const envContent = `# NumiCoin Production Environment Configuration
# Generated on ${new Date().toISOString()}
# Network: ${network}

# Contract Addresses
NEXT_PUBLIC_NUMICOIN_ADDRESS=${numiCoinAddress}
NEXT_PUBLIC_MINING_POOL_ADDRESS=${miningPoolAddress}

# Network Configuration
NEXT_PUBLIC_NETWORK_NAME=${network}
NEXT_PUBLIC_CHAIN_ID=${hre.network.config.chainId}

# RPC URLs (update with your production providers)
NEXT_PUBLIC_RPC_URL=${hre.network.config.url || "https://mainnet.infura.io/v3/your_project_id"}

# Etherscan API Key for contract verification
ETHERSCAN_API_KEY=${process.env.ETHERSCAN_API_KEY || "your_etherscan_api_key_here"}

# Production Settings
NODE_ENV=production
NEXT_PUBLIC_IS_PRODUCTION=true

# Monitoring (optional)
SENTRY_DSN=your_sentry_dsn_here
ANALYTICS_ID=your_analytics_id_here
`;

    const envPath = path.join(__dirname, "..", ".env.production");
    fs.writeFileSync(envPath, envContent);
    console.log("✅ Production environment file generated:", envPath);

    // Generate frontend configuration
    const frontendConfig = {
      contracts: {
        numiCoin: numiCoinAddress,
        miningPool: miningPoolAddress
      },
      network: {
        name: network,
        chainId: hre.network.config.chainId,
        rpcUrl: hre.network.config.url || "https://mainnet.infura.io/v3/your_project_id"
      },
      mining: {
        initialDifficulty: 4,
        blockReward: "100",
        targetMineTime: 600
      },
      production: {
        isProduction: true,
        monitoring: true,
        analytics: true
      }
    };

    const configPath = path.join(__dirname, "..", "frontend-config-production.json");
    fs.writeFileSync(configPath, JSON.stringify(frontendConfig, null, 2));
    console.log("✅ Production frontend config generated:", configPath);

    // Step 5: Contract Verification
    if (process.env.ETHERSCAN_API_KEY) {
      console.log("\n🔍 Step 5: Verifying Contracts...");
      
      try {
        console.log("Verifying NumiCoin contract...");
        await hre.run("verify:verify", {
          address: numiCoinAddress,
          constructorArguments: []
        });
        console.log("✅ NumiCoin verified on Etherscan");
        
        console.log("Verifying MiningPool contract...");
        await hre.run("verify:verify", {
          address: miningPoolAddress,
          constructorArguments: [numiCoinAddress]
        });
        console.log("✅ MiningPool verified on Etherscan");
        
        deploymentInfo.production.verified = true;
        fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
      } catch (error) {
        console.warn("⚠️  Contract verification failed:", error.message);
      }
    }

    // Step 6: Production Setup Instructions
    console.log("\n🎉 Production Deployment Complete!");
    console.log("\n📋 Contract Addresses:");
    console.log("NumiCoin:", numiCoinAddress);
    console.log("MiningPool:", miningPoolAddress);
    console.log("Deployer:", deployer.address);

    console.log("\n📖 Production Setup Instructions:");
    console.log("1. Update your frontend environment variables:");
    console.log(`   NEXT_PUBLIC_NUMICOIN_ADDRESS=${numiCoinAddress}`);
    console.log(`   NEXT_PUBLIC_MINING_POOL_ADDRESS=${miningPoolAddress}`);
    console.log("2. Deploy your frontend to production");
    console.log("3. Set up monitoring and analytics");
    console.log("4. Configure backup RPC providers");
    console.log("5. Set up automated testing");
    console.log("6. Monitor contract events and transactions");

    console.log("\n🔍 Verification Commands:");
    console.log(`npx hardhat verify --network ${network} ${numiCoinAddress}`);
    console.log(`npx hardhat verify --network ${network} ${miningPoolAddress} "${numiCoinAddress}"`);

    console.log("\n📊 Monitoring Setup:");
    console.log("1. Set up Etherscan API monitoring");
    console.log("2. Configure transaction monitoring");
    console.log("3. Set up event monitoring for mining activity");
    console.log("4. Configure alerting for critical events");

    console.log("\n🚀 Next Steps:");
    console.log("1. Test all functionality on production contracts");
    console.log("2. Monitor gas usage and optimize if needed");
    console.log("3. Set up community governance");
    console.log("4. Launch marketing campaign");
    console.log("5. Monitor network health and performance");

    console.log("\n💡 Production Best Practices:");
    console.log("- Keep private keys secure and use hardware wallets");
    console.log("- Monitor contract events regularly");
    console.log("- Have emergency procedures ready");
    console.log("- Regular security audits");
    console.log("- Community feedback and testing");

    console.log("\n🎯 Ready for Production!");

  } catch (error) {
    console.error("❌ Production deployment failed:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Production deployment failed:", error);
    process.exit(1);
  }); 