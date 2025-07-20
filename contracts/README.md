# NumiCoin Smart Contracts

This directory contains the smart contracts for the NumiCoin mining ecosystem, including the main token contract, mining pool, and deployment scripts.

## Overview

The NumiCoin ecosystem consists of:

1. **NumiCoin.sol** - Main ERC-20 token with built-in mining functionality
2. **MiningPool.sol** - Mining pool for collaborative mining and reward sharing
3. **DeployContracts.sol** - Deployment script for the entire ecosystem

## Features

### NumiCoin Token
- ERC-20 compliant token with 18 decimals
- Built-in proof-of-work mining system
- Dynamic difficulty adjustment
- Anti-spam measures for consecutive mining
- Real-time mining statistics

### Mining Pool
- Collaborative mining with shared rewards
- Staking-based participation
- Automatic reward distribution
- Pool fee system (5% default)
- Flexible entry/exit

## Prerequisites

- Node.js 18+ and npm
- Hardhat development environment
- MetaMask or similar wallet
- Testnet ETH for deployment

## Installation

1. Navigate to the contracts directory:
```bash
cd contracts
```

2. Install dependencies:
```bash
npm install
```

3. Create environment file:
```bash
cp .env.example .env
```

4. Configure your environment variables in `.env`:
```env
PRIVATE_KEY=your_private_key_here
SEPOLIA_URL=https://sepolia.infura.io/v3/your_project_id
POLYGON_URL=https://polygon-rpc.com
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Deployment

### Local Development

1. Start local Hardhat node:
```bash
npm run node
```

2. Deploy contracts locally:
```bash
npm run deploy:local
```

### Testnet Deployment

1. Deploy to Sepolia testnet:
```bash
npm run deploy:sepolia
```

2. Deploy to Polygon Mumbai testnet:
```bash
npm run deploy:polygon
```

### Mainnet Deployment

1. Deploy to Ethereum mainnet:
```bash
npm run deploy:mainnet
```

## Contract Addresses

After deployment, the script will output contract addresses and save them to `deployment.json`. Update your frontend environment variables:

```env
NEXT_PUBLIC_NUMICOIN_ADDRESS=0x...
NEXT_PUBLIC_MINING_POOL_ADDRESS=0x...
```

## Testing

Run the test suite:
```bash
npm test
```

Run with coverage:
```bash
npm run coverage
```

## Contract Verification

Verify contracts on Etherscan:
```bash
npm run verify
```

## Usage

### Mining

1. **Start Mining**: Call `mineBlock(nonce, blockData)` with a valid nonce that produces a hash meeting the current difficulty requirement.

2. **Difficulty**: The contract automatically adjusts difficulty based on mining speed to maintain ~10-minute block times.

3. **Rewards**: Each successfully mined block rewards 100 NUMI tokens (reduced by 50% for consecutive mining).

### Mining Pool

1. **Join Pool**: Stake NUMI tokens to join the mining pool and earn proportional rewards.

2. **Claim Rewards**: Claim accumulated rewards without leaving the pool.

3. **Leave Pool**: Withdraw your stake and all accumulated rewards.

## Gas Optimization

The contracts are optimized for gas efficiency:
- Minimal storage operations
- Efficient event emission
- Optimized loops and calculations
- Reentrancy protection

## Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **Ownable**: Restricted admin functions
- **Input Validation**: Comprehensive parameter checks
- **Anti-Spam**: Consecutive mining penalties
- **Safe Math**: Built-in overflow protection (Solidity 0.8+)

## Architecture

```
NumiCoin Ecosystem
├── NumiCoin.sol (Main Token)
│   ├── ERC-20 functionality
│   ├── Mining logic
│   ├── Difficulty adjustment
│   └── Reward distribution
├── MiningPool.sol (Mining Pool)
│   ├── Staking mechanism
│   ├── Reward sharing
│   ├── Pool management
│   └── Fee collection
└── DeployContracts.sol (Deployment)
    ├── Contract deployment
    ├── Initialization
    └── Address management
```

## Events

### NumiCoin Events
- `BlockMined`: Emitted when a block is successfully mined
- `DifficultyAdjusted`: Emitted when difficulty is adjusted

### MiningPool Events
- `MinerJoined`: Emitted when a miner joins the pool
- `MinerLeft`: Emitted when a miner leaves the pool
- `RewardsClaimed`: Emitted when rewards are claimed
- `PoolReward`: Emitted when rewards are added to the pool

## Monitoring

Monitor contract events and transactions:
- Block explorers (Etherscan, Polygonscan)
- Web3 event listeners
- Hardhat console logs

## Troubleshooting

### Common Issues

1. **Insufficient Gas**: Increase gas limit for mining transactions
2. **Invalid Nonce**: Ensure nonce produces valid hash for current difficulty
3. **Pool Full**: Check maximum stake limits
4. **Network Congestion**: Use higher gas prices during peak times

### Debug Commands

```bash
# Check contract state
npx hardhat console --network localhost
> const contract = await ethers.getContractAt("NumiCoin", "0x...")
> await contract.getMiningStats()

# Verify deployment
npx hardhat verify --network sepolia 0x... "constructor_args"
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

For questions and support:
- Create an issue on GitHub
- Join our Discord community
- Check the documentation

---

**Note**: This is a production-ready implementation. Always test thoroughly on testnets before mainnet deployment. 