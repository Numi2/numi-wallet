# NumiCoin Deployment Guide

This guide will walk you through deploying the complete NumiCoin mining ecosystem with real smart contracts.

## Prerequisites

- Node.js 18+ and npm
- MetaMask or similar wallet
- Testnet ETH (for testnet deployment)
- Git

## Quick Start

### 1. Install Dependencies

```bash
# Install frontend dependencies
npm install

# Install smart contract dependencies
cd contracts
npm install
```

### 2. Deploy Smart Contracts

#### Option A: Local Development (Recommended for testing)

```bash
# Start local Hardhat node
cd contracts
npm run node

# In a new terminal, deploy contracts
npm run setup-ecosystem
```

#### Option B: Testnet Deployment

```bash
# Set up environment variables
cd contracts
cp .env.example .env

# Edit .env with your configuration
PRIVATE_KEY=your_private_key_here
SEPOLIA_URL=https://sepolia.infura.io/v3/your_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key

# Deploy to Sepolia testnet
npm run setup-ecosystem -- --network sepolia
```

#### Option C: Mainnet Deployment

```bash
# Set up environment variables for mainnet
cd contracts
cp .env.example .env

# Edit .env with mainnet configuration
PRIVATE_KEY=your_private_key_here
MAINNET_URL=https://mainnet.infura.io/v3/your_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key

# Deploy to mainnet (BE CAREFUL!)
npm run setup-ecosystem -- --network mainnet
```

### 3. Configure Frontend

After deployment, the script will generate configuration files. Copy the environment variables to your frontend:

```bash
# Copy generated environment file
cp contracts/.env.local .env.local

# Or manually add to your .env.local:
NEXT_PUBLIC_NUMICOIN_ADDRESS=0x...
NEXT_PUBLIC_MINING_POOL_ADDRESS=0x...
NEXT_PUBLIC_RPC_URL=your_rpc_url
```

### 4. Start the Application

```bash
# Start the development server
npm run dev
```

## Smart Contract Details

### NumiCoin Contract
- **Token**: ERC-20 compliant with 18 decimals
- **Mining**: Proof-of-work with dynamic difficulty
- **Rewards**: 100 NUMI per block (reduced for consecutive mining)
- **Features**: Anti-spam measures, real-time statistics

### Mining Pool Contract
- **Staking**: Minimum 100 NUMI, maximum 10,000 NUMI
- **Rewards**: Proportional to stake amount
- **Fees**: 5% pool fee
- **Features**: Flexible entry/exit, automatic distribution

## Testing

### Run Tests
```bash
cd contracts
npm test
```

### Test Mining
1. Start the application
2. Create or import a wallet
3. Navigate to the mining page
4. Start mining and watch for block confirmations

### Test Pool
1. Mine some NUMI tokens
2. Join the mining pool with your tokens
3. Monitor pool rewards
4. Claim rewards or leave the pool

## Verification

### Verify on Etherscan
```bash
cd contracts
npx hardhat verify --network sepolia 0x... # NumiCoin address
npx hardhat verify --network sepolia 0x... "0x..." # MiningPool address with NumiCoin address
```

## Monitoring

### Contract Events
Monitor these events for mining activity:
- `BlockMined`: New blocks found
- `DifficultyAdjusted`: Difficulty changes
- `MinerJoined/Left`: Pool activity
- `RewardsClaimed`: Reward distributions

### Block Explorer
- **Sepolia**: https://sepolia.etherscan.io
- **Polygon**: https://polygonscan.com
- **Mainnet**: https://etherscan.io

## Troubleshooting

### Common Issues

1. **Insufficient Gas**
   - Increase gas limit for mining transactions
   - Use higher gas prices during network congestion

2. **Contract Not Found**
   - Verify contract addresses in environment variables
   - Check network configuration

3. **Mining Not Working**
   - Ensure wallet is connected
   - Check if contracts are deployed
   - Verify RPC URL is correct

4. **Pool Issues**
   - Check minimum/maximum stake requirements
   - Ensure sufficient NUMI balance
   - Verify pool contract is properly linked

### Debug Commands

```bash
# Check contract state
cd contracts
npx hardhat console --network localhost
> const contract = await ethers.getContractAt("NumiCoin", "0x...")
> await contract.getMiningStats()

# Check deployment
cat deployment.json
```

## Security Considerations

### Before Mainnet
- [ ] Audit smart contracts
- [ ] Test thoroughly on testnets
- [ ] Verify all contract addresses
- [ ] Set up monitoring and alerts
- [ ] Have emergency procedures ready

### Best Practices
- Use hardware wallets for mainnet deployment
- Keep private keys secure
- Monitor contract events
- Regular security updates
- Community feedback and testing

## Support

If you encounter issues:
1. Check the troubleshooting section
2. Review contract documentation
3. Test on local network first
4. Create an issue on GitHub

## Next Steps

After successful deployment:
1. **Marketing**: Promote your mining ecosystem
2. **Community**: Build a mining community
3. **Features**: Add more advanced mining features
4. **Scaling**: Optimize for higher transaction volumes
5. **Governance**: Implement DAO governance

---

**Remember**: Always test thoroughly before mainnet deployment. The contracts are production-ready but should be audited for your specific use case. 