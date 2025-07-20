# NumiCoin Mainnet Deployment Guide

## 🚀 **Making NumiCoin Real - Complete Deployment Guide**

### **Prerequisites**

1. **Ethereum Wallet with ETH**
   - At least 3-4 ETH for deployment costs
   - Private key for deployment account

2. **API Keys**
   - Infura/Alchemy RPC endpoint
   - Etherscan API key for contract verification

3. **Development Environment**
   - Node.js and npm installed
   - Hardhat configured

## 📋 **Step 1: Environment Setup**

Create a `.env` file in the project root:

```env
# Ethereum Mainnet Configuration
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID
GOERLI_RPC_URL=https://goerli.infura.io/v3/YOUR_INFURA_PROJECT_ID

# Deployment Account
PRIVATE_KEY=your_private_key_here

# API Keys
ETHERSCAN_API_KEY=your_etherscan_api_key_here
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key_here

# Gas Reporting
REPORT_GAS=true
```

## 🔧 **Step 2: Install Dependencies**

```bash
npm install
npm install --save-dev @nomicfoundation/hardhat-toolbox dotenv
```

## 🧪 **Step 3: Test on Testnet (Recommended)**

Before deploying to mainnet, test on Goerli testnet:

```bash
# Deploy to Goerli testnet
npx hardhat run scripts/deploy-numicoin.js --network goerli

# Set the environment variable for mining pool
export NUMICOIN_ADDRESS=0x... # Address from previous deployment

# Deploy mining pool
npx hardhat run scripts/deploy-mining-pool.js --network goerli
```

## 🚀 **Step 4: Deploy to Ethereum Mainnet**

### **4.1 Deploy NumiCoin Contract**

```bash
# Deploy the main token contract
npx hardhat run scripts/deploy-numicoin.js --network mainnet
```

**Expected Output:**
```
🚀 Deploying NumiCoin to Ethereum Mainnet...
Deploying contracts with account: 0x...
Account balance: 4000000000000000000
📝 Deploying NumiCoin contract...
✅ NumiCoin deployed to: 0x...
📊 Contract Details:
   - Initial Difficulty: 2
   - Block Reward: 0.005 NUMI
   - Target Block Time: 600 seconds
   - Governance Threshold: 1000.0 NUMI
   - Owner: 0x...
```

### **4.2 Deploy MiningPool Contract**

```bash
# Set the NumiCoin address from previous deployment
export NUMICOIN_ADDRESS=0x... # Address from step 4.1

# Deploy the mining pool contract
npx hardhat run scripts/deploy-mining-pool.js --network mainnet
```

**Expected Output:**
```
🚀 Deploying MiningPool to Ethereum Mainnet...
📝 Using NumiCoin address: 0x...
📝 Deploying MiningPool contract...
✅ MiningPool deployed to: 0x...
📊 Contract Details:
   - NumiCoin Address: 0x...
   - Pool Fee: 200 basis points (2%)
   - Owner: 0x...
```

## ✅ **Step 5: Verify Contracts on Etherscan**

### **5.1 Verify NumiCoin Contract**

```bash
npx hardhat verify --network mainnet 0xNUMICOIN_ADDRESS 2 "5000000000000000" 600 "1000000000000000000000" "0xOWNER_ADDRESS"
```

### **5.2 Verify MiningPool Contract**

```bash
npx hardhat verify --network mainnet 0xMININGPOOL_ADDRESS 0xNUMICOIN_ADDRESS 200 "0xOWNER_ADDRESS"
```

## 🔄 **Step 6: Update Frontend**

### **6.1 Update Environment Variables**

Add these to your Vercel environment variables:

```env
NEXT_PUBLIC_NUMICOIN_ADDRESS=0x... # From step 4.1
NEXT_PUBLIC_MINING_POOL_ADDRESS=0x... # From step 4.2
NEXT_PUBLIC_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID
NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_EXPLORER_URL=https://etherscan.io
```

### **6.2 Deploy Updated Frontend**

```bash
vercel --prod
```

## 🎯 **Step 7: Test Real Mining**

1. **Visit the deployed app**
2. **Create or import a wallet**
3. **Navigate to the miner page**
4. **Start mining real NUMI tokens**
5. **Verify rewards in your wallet**

## 💰 **Cost Breakdown**

### **Deployment Costs**
- **NumiCoin Contract**: ~1.5-2 ETH (~$3,000-4,000)
- **MiningPool Contract**: ~1-1.5 ETH (~$2,000-3,000)
- **Total**: ~2.5-3.5 ETH (~$5,000-7,000)

### **User Mining Costs**
- **Gas per block**: ~50,000-100,000 gas
- **Cost per block**: ~$10-50 (depending on gas prices)
- **Users pay their own gas fees**

## 🚨 **Important Notes**

### **Security Considerations**
- **Private Key Security**: Never commit private keys to git
- **Contract Ownership**: Keep owner private key secure
- **Emergency Functions**: Available for adjustments if needed

### **Economic Considerations**
- **Difficulty Adjustment**: Monitors and adjusts automatically
- **Gas Optimization**: Contracts optimized for efficiency
- **Fair Distribution**: No initial token distribution

### **User Experience**
- **Gas Estimation**: Frontend shows estimated gas costs
- **Network Detection**: Warns users if not on mainnet
- **Error Handling**: Clear error messages for users

## 📊 **Monitoring and Maintenance**

### **Post-Deployment Tasks**
1. **Monitor contract activity** on Etherscan
2. **Track mining difficulty** and adjust if needed
3. **Monitor gas prices** and optimize if necessary
4. **Gather user feedback** and iterate
5. **Community building** and marketing

### **Emergency Procedures**
- **Difficulty Adjustment**: Use owner functions if needed
- **Gas Optimization**: Update contracts if gas costs too high
- **Bug Fixes**: Deploy new contracts if critical issues found

## 🎉 **Launch Checklist**

- [ ] Contracts deployed to mainnet
- [ ] Contracts verified on Etherscan
- [ ] Frontend updated with contract addresses
- [ ] Environment variables configured
- [ ] Mining functionality tested
- [ ] Staking functionality tested
- [ ] Governance functionality tested
- [ ] Community announcement prepared
- [ ] Monitoring tools set up

## 🌟 **The Result**

After successful deployment, NumiCoin will be:

- **Real ERC-20 token** on Ethereum mainnet
- **Mineable by anyone** with a computer
- **Fair distribution** through mining only
- **Democratic governance** through staking
- **Accessible to everyone** (easy mining)

**NumiCoin - The People's Coin** will be live on the Ethereum blockchain! 🚀

---

**Need help?** Check the troubleshooting section or reach out to the community. 