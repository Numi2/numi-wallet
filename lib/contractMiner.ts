import { ethers } from "ethers";
import { getProvider } from "./wallet";

// Contract ABIs
const NUMICOIN_ABI = [
  "function mineBlock(uint256 nonce, bytes calldata blockData) external",
  "function getMiningStats() external view returns (uint256, uint256, uint256, uint256, uint256)",
  "function getMinerStats(address miner) external view returns (uint256, uint256, uint256)",
  "function isValidHash(bytes32 hash) external view returns (bool)",
  "function calculateReward(address miner) external view returns (uint256)",
  "function currentBlock() external view returns (uint256)",
  "function difficulty() external view returns (uint256)",
  "function blockReward() external view returns (uint256)",
  "event BlockMined(uint256 indexed blockNumber, address indexed miner, bytes32 blockHash, uint256 nonce, uint256 reward, uint256 timestamp)",
  "event DifficultyAdjusted(uint256 oldDifficulty, uint256 newDifficulty)"
];

const MINING_POOL_ABI = [
  "function joinPool(uint256 amount) external",
  "function leavePool() external",
  "function claimRewards() external",
  "function getMinerInfo(address miner) external view returns (uint256, uint256, uint256, bool)",
  "function getPoolStats() external view returns (uint256, uint256, uint256, uint256, uint256)",
  "function calculatePendingRewards(address miner) external view returns (uint256)",
  "event MinerJoined(address indexed miner, uint256 shares)",
  "event MinerLeft(address indexed miner, uint256 shares)",
  "event RewardsClaimed(address indexed miner, uint256 amount)"
];

export interface ContractMiningStats {
  currentBlock: number;
  difficulty: number;
  blockReward: string;
  lastMineTime: number;
  targetMineTime: number;
  hashesPerSecond: number;
  totalHashes: number;
  isMining: boolean;
}

export interface MinerStats {
  totalRewards: string;
  lastMinedBlock: number;
  currentReward: string;
}

export interface PoolStats {
  totalShares: string;
  totalRewards: string;
  lastRewardTime: number;
  rewardPerShare: string;
  activeMiners: number;
}

export interface PoolMinerInfo {
  shares: string;
  pendingRewards: string;
  lastClaimTime: number;
  isActive: boolean;
}

class ContractMiner {
  private numiCoinContract: any;
  private miningPoolContract: any;
  private provider: ethers.Provider;
  private wallet: ethers.Wallet | null = null;
  private workers: Worker[] = [];
  private isRunning: boolean = false;
  private stats: ContractMiningStats;
  private _onStatsUpdate?: (stats: ContractMiningStats) => void;
  private _onBlockMined?: (result: any) => void;
  private statsInterval?: NodeJS.Timeout;

  constructor(
    numiCoinAddress: string,
    miningPoolAddress: string,
    provider: ethers.Provider
  ) {
    this.provider = provider;
    this.numiCoinContract = new ethers.Contract(
      numiCoinAddress,
      NUMICOIN_ABI,
      provider
    );
    this.miningPoolContract = new ethers.Contract(
      miningPoolAddress,
      MINING_POOL_ABI,
      provider
    );

    this.stats = {
      currentBlock: 1,
      difficulty: 4,
      blockReward: "0",
      lastMineTime: 0,
      targetMineTime: 600, // 10 minutes
      hashesPerSecond: 0,
      totalHashes: 0,
      isMining: false,
    };

    // Listen for mining events
    this.setupEventListeners();
  }

  /**
   * Set the wallet for mining transactions
   */
  setWallet(wallet: ethers.Wallet): void {
    this.wallet = wallet;
    this.numiCoinContract = this.numiCoinContract.connect(wallet);
    this.miningPoolContract = this.miningPoolContract.connect(wallet);
  }

  /**
   * Start mining with the specified number of workers
   */
  async startMining(workerCount: number = 4): Promise<void> {
    if (this.isRunning) {
      throw new Error("Mining is already running");
    }

    if (!this.wallet) {
      throw new Error("Wallet not set");
    }

    this.isRunning = true;
    this.stats.isMining = true;

    // Load current contract stats
    await this.updateContractStats();

    // Create Web Workers for mining
    for (let i = 0; i < workerCount; i++) {
      const worker = this.createMiningWorker(i);
      this.workers.push(worker);
    }

    // Start stats monitoring
    this.startStatsMonitoring();

    console.log(`Started mining with ${this.workers.length} workers`);
  }

  /**
   * Stop mining
   */
  stopMining(): void {
    if (!this.isRunning) return;

    this.isRunning = false;
    this.stats.isMining = false;

    // Terminate all workers
    this.workers.forEach(worker => worker.terminate());
    this.workers = [];

    // Clear stats interval
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
      this.statsInterval = undefined;
    }

    console.log("Mining stopped");
  }

  /**
   * Create a Web Worker for mining
   */
  private createMiningWorker(workerId: number): Worker {
    const workerCode = `
      let hashesCount = 0;
      let startTime = Date.now();
      let isRunning = false;
      let currentDifficulty = 4;
      let currentBlock = 1;

      self.onmessage = function(e) {
        const { type, data } = e.data;
        
        switch (type) {
          case 'start':
            isRunning = true;
            currentDifficulty = data.difficulty;
            currentBlock = data.blockNumber;
            hashesCount = 0;
            startTime = Date.now();
            startMining();
            break;
          case 'stop':
            isRunning = false;
            break;
          case 'updateDifficulty':
            currentDifficulty = data.difficulty;
            break;
          case 'getStats':
            const now = Date.now();
            const elapsed = (now - startTime) / 1000;
            const hps = elapsed > 0 ? Math.floor(hashesCount / elapsed) : 0;
            self.postMessage({
              type: 'stats',
              data: { hashesCount, hashesPerSecond: hps }
            });
            break;
        }
      };

      function startMining() {
        let nonce = 0;
        
        function mine() {
          if (!isRunning) return;
          
          // Create block data for hashing
          const blockData = {
            blockNumber: currentBlock,
            nonce: nonce,
            timestamp: Date.now()
          };
          
          // Hash the block data
          const blockString = JSON.stringify(blockData);
          const hash = sha256Hash(blockString);
          hashesCount++;
          
          // Check if hash meets difficulty requirement
          if (isValidHash(hash, currentDifficulty)) {
            self.postMessage({
              type: 'blockFound',
              data: {
                blockNumber: currentBlock,
                hash: hash,
                nonce: nonce,
                blockData: blockString
              }
            });
            return;
          }
          
          nonce++;
          
          // Continue mining
          setTimeout(mine, 0);
        }
        
        mine();
      }

      function sha256Hash(str) {
        // Simple hash function for mining
        let hash = 0;
        const prime = 31;
        
        for (let i = 0; i < str.length; i++) {
          hash = (hash * prime + str.charCodeAt(i)) >>> 0;
        }
        
        // Convert to hex and ensure it's 64 characters
        let hex = hash.toString(16);
        while (hex.length < 64) {
          hex = '0' + hex;
        }
        
        return hex;
      }

      function isValidHash(hash, difficulty) {
        // Check if hash starts with required number of zeros
        const target = '0'.repeat(difficulty);
        return hash.startsWith(target);
      }
    `;

    const blob = new Blob([workerCode], { type: 'application/javascript' });
    const worker = new Worker(URL.createObjectURL(blob));

    worker.onmessage = (e) => {
      const { type, data } = e.data;
      
      switch (type) {
        case 'stats':
          this.updateWorkerStats(workerId, data);
          break;
        case 'blockFound':
          this.handleBlockFound(data);
          break;
      }
    };

    return worker;
  }

  /**
   * Handle when a block is found by a worker
   */
  private async handleBlockFound(blockData: any): Promise<void> {
    try {
      if (!this.wallet) return;

      // Submit the block to the smart contract
      const tx = await this.numiCoinContract.mineBlock(
        blockData.nonce,
        ethers.toUtf8Bytes(blockData.blockData)
      );

      console.log("Block submitted to contract:", tx.hash);

      // Wait for transaction confirmation
      const receipt = await tx.wait();
      
      if (receipt.status === 1) {
        console.log("Block successfully mined!");
        
        // Update stats
        await this.updateContractStats();
        
        // Notify listeners
        if (this._onBlockMined) {
          this._onBlockMined({
            blockNumber: blockData.blockNumber,
            hash: blockData.hash,
            nonce: blockData.nonce,
            txHash: tx.hash
          });
        }
      }
    } catch (error) {
      console.error("Failed to submit block:", error);
    }
  }

  /**
   * Update worker statistics
   */
  private updateWorkerStats(workerId: number, workerStats: any): void {
    this.stats.hashesPerSecond += workerStats.hashesPerSecond;
    this.stats.totalHashes += workerStats.hashesCount;
  }

  /**
   * Start monitoring mining statistics
   */
  private startStatsMonitoring(): void {
    this.statsInterval = setInterval(async () => {
      // Reset hashes per second
      this.stats.hashesPerSecond = 0;
      
      // Request stats from all workers
      this.workers.forEach(worker => {
        worker.postMessage({ type: 'getStats' });
      });

      // Update contract stats
      await this.updateContractStats();

      // Notify listeners
      if (this._onStatsUpdate) {
        this._onStatsUpdate({ ...this.stats });
      }
    }, 1000);
  }

  /**
   * Update statistics from the smart contract
   */
  private async updateContractStats(): Promise<void> {
    try {
      const [currentBlock, difficulty, blockReward, lastMineTime, targetMineTime] = 
        await this.numiCoinContract.getMiningStats();

      this.stats.currentBlock = Number(currentBlock);
      this.stats.difficulty = Number(difficulty);
      this.stats.blockReward = ethers.formatEther(blockReward);
      this.stats.lastMineTime = Number(lastMineTime);
      this.stats.targetMineTime = Number(targetMineTime);

      // Update workers with new difficulty
      this.workers.forEach(worker => {
        worker.postMessage({
          type: 'updateDifficulty',
          data: { difficulty: this.stats.difficulty }
        });
      });
    } catch (error) {
      console.error("Failed to update contract stats:", error);
    }
  }

  /**
   * Setup event listeners for mining events
   */
  private setupEventListeners(): void {
    this.numiCoinContract.on("BlockMined", (blockNumber: any, miner: any, blockHash: any, nonce: any, reward: any, timestamp: any) => {
      console.log("Block mined event:", {
        blockNumber: blockNumber.toString(),
        miner,
        reward: ethers.formatEther(reward)
      });
    });

    this.numiCoinContract.on("DifficultyAdjusted", (oldDifficulty: any, newDifficulty: any) => {
      console.log("Difficulty adjusted:", {
        old: oldDifficulty.toString(),
        new: newDifficulty.toString()
      });
    });
  }

  /**
   * Get current mining statistics
   */
  async getMiningStats(): Promise<ContractMiningStats> {
    await this.updateContractStats();
    return { ...this.stats };
  }

  /**
   * Get miner statistics
   */
  async getMinerStats(address: string): Promise<MinerStats> {
    const [totalRewards, lastMinedBlock, currentReward] = 
      await this.numiCoinContract.getMinerStats(address);

    return {
      totalRewards: ethers.formatEther(totalRewards),
      lastMinedBlock: Number(lastMinedBlock),
      currentReward: ethers.formatEther(currentReward)
    };
  }

  /**
   * Get pool statistics
   */
  async getPoolStats(): Promise<PoolStats> {
    const [totalShares, totalRewards, lastRewardTime, rewardPerShare, activeMiners] = 
      await this.miningPoolContract.getPoolStats();

    return {
      totalShares: ethers.formatEther(totalShares),
      totalRewards: ethers.formatEther(totalRewards),
      lastRewardTime: Number(lastRewardTime),
      rewardPerShare: ethers.formatEther(rewardPerShare),
      activeMiners: Number(activeMiners)
    };
  }

  /**
   * Get pool miner information
   */
  async getPoolMinerInfo(address: string): Promise<PoolMinerInfo> {
    const [shares, pendingRewards, lastClaimTime, isActive] = 
      await this.miningPoolContract.getMinerInfo(address);

    return {
      shares: ethers.formatEther(shares),
      pendingRewards: ethers.formatEther(pendingRewards),
      lastClaimTime: Number(lastClaimTime),
      isActive
    };
  }

  /**
   * Join mining pool
   */
  async joinPool(amount: string): Promise<void> {
    if (!this.wallet) throw new Error("Wallet not set");
    
    const amountWei = ethers.parseEther(amount);
    const tx = await this.miningPoolContract.joinPool(amountWei);
    await tx.wait();
  }

  /**
   * Leave mining pool
   */
  async leavePool(): Promise<void> {
    if (!this.wallet) throw new Error("Wallet not set");
    
    const tx = await this.miningPoolContract.leavePool();
    await tx.wait();
  }

  /**
   * Claim pool rewards
   */
  async claimPoolRewards(): Promise<void> {
    if (!this.wallet) throw new Error("Wallet not set");
    
    const tx = await this.miningPoolContract.claimRewards();
    await tx.wait();
  }

  /**
   * Set callbacks
   */
  onStatsUpdate(callback: (stats: ContractMiningStats) => void): void {
    this._onStatsUpdate = callback;
  }

  onBlockMined(callback: (result: any) => void): void {
    this._onBlockMined = callback;
  }

  /**
   * Check if mining is running
   */
  isMining(): boolean {
    return this.isRunning;
  }
}

// Export the class
export { ContractMiner }; 