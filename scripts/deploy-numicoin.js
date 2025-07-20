const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying NumiCoin to Ethereum Mainnet...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy NumiCoin contract
  const NumiCoin = await ethers.getContractFactory("NumiCoin");
  
  console.log("📝 Deploying NumiCoin contract...");
  
  const numiCoin = await NumiCoin.deploy(
    2, // Initial difficulty (easy mining for people's coin)
    ethers.utils.parseEther("0.005"), // Block reward: 0.005 NUMI
    600, // Target block time: 10 minutes
    ethers.utils.parseEther("1000"), // Governance threshold: 1000 NUMI staked
    deployer.address // Owner address
  );

  await numiCoin.deployed();

  console.log("✅ NumiCoin deployed to:", numiCoin.address);
  console.log("📊 Contract Details:");
  console.log("   - Initial Difficulty:", await numiCoin.difficulty());
  console.log("   - Block Reward:", ethers.utils.formatEther(await numiCoin.blockReward()), "NUMI");
  console.log("   - Target Block Time:", await numiCoin.targetMineTime(), "seconds");
  console.log("   - Governance Threshold:", ethers.utils.formatEther(await numiCoin.governanceThreshold()), "NUMI");
  console.log("   - Owner:", await numiCoin.owner());

  // Verify the deployment
  console.log("\n🔍 Verifying deployment...");
  const currentBlock = await numiCoin.currentBlock();
  const totalSupply = await numiCoin.totalSupply();
  
  console.log("   - Current Block:", currentBlock.toString());
  console.log("   - Total Supply:", ethers.utils.formatEther(totalSupply), "NUMI");
  console.log("   - No initial distribution (People's Coin philosophy)");

  // Save deployment info
  const deploymentInfo = {
    network: "ethereum-mainnet",
    contract: "NumiCoin",
    address: numiCoin.address,
    deployer: deployer.address,
    blockNumber: await numiCoin.provider.getBlockNumber(),
    timestamp: Date.now(),
    parameters: {
      initialDifficulty: 2,
      blockReward: "0.005 NUMI",
      targetBlockTime: "600 seconds (10 minutes)",
      governanceThreshold: "1000 NUMI",
      owner: deployer.address
    }
  };

  console.log("\n📄 Deployment Info:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  console.log("\n🎉 NumiCoin successfully deployed to Ethereum Mainnet!");
  console.log("🔗 Contract Address:", numiCoin.address);
  console.log("🌐 Etherscan URL: https://etherscan.io/address/" + numiCoin.address);
  
  console.log("\n📋 Next Steps:");
  console.log("1. Verify contract on Etherscan");
  console.log("2. Deploy MiningPool contract");
  console.log("3. Update frontend with contract address");
  console.log("4. Test mining functionality");
  console.log("5. Announce launch to community");

  return numiCoin.address;
}

main()
  .then((address) => {
    console.log("\n✅ Deployment script completed successfully!");
    console.log("Contract address:", address);
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }); 