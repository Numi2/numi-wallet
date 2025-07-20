import { ethers } from "ethers";
import { addMiningReward } from "./wallet";

export interface MiningStats {
  hashesPerSecond: number;
  totalHashes: number;
  difficulty: number;
  blocksMined: number;
  currentBlock: number;
  isMining: boolean;
  lastBlockTime?: number;
}

export interface MiningConfig {
  difficulty: number;
  blockReward: number;
  maxWorkers: number;
  updateInterval: number;
}

export interface MiningResult {
  blockNumber: number;
  hash: string;
  nonce: number;
  timestamp: number;
  reward: number;
  difficulty: number;
}

// Default mining configuration - MADE MUCH EASIER FOR PEOPLE'S COIN
const DEFAULT_CONFIG: MiningConfig = {
  difficulty: 2, // Reduced from 4 to 2 - much easier to mine!
  blockReward: 0.005, // Increased from 0.001 to 0.005 - more generous rewards!
  maxWorkers: navigator.hardwareConcurrency || 4,
  updateInterval: 500, // Reduced from 1000 to 500ms - more responsive updates
};

class NumiMiner {
  private config: MiningConfig;
  private stats: MiningStats;
  private workers: Worker[] = [];
  private isRunning: boolean = false;
  private currentBlock: number = 1;
  private _onStatsUpdate?: (stats: MiningStats) => void;
  private _onBlockMined?: (result: MiningResult) => void;
  private statsInterval?: NodeJS.Timeout;

  constructor(config: Partial<MiningConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.stats = {
      hashesPerSecond: 0,
      totalHashes: 0,
      difficulty: this.config.difficulty,
      blocksMined: 0,
      currentBlock: this.currentBlock,
      isMining: false,
    };
  }

  /**
   * Start mining with the specified number of workers
   */
  async startMining(): Promise<void> {
    if (this.isRunning) {
      throw new Error("Mining is already running");
    }

    this.isRunning = true;
    this.stats.isMining = true;
    this.stats.currentBlock = this.currentBlock;
    this.stats.hashesPerSecond = 0;
    this.stats.totalHashes = 0;

    // Create Web Workers for mining
    for (let i = 0; i < this.config.maxWorkers; i++) {
      const worker = this.createMiningWorker(i);
      this.workers.push(worker);
    }

    // Start mining on all workers
    this.startNextBlock();

    // Start stats monitoring
    this.startStatsMonitoring();

    console.log(`Started mining with ${this.workers.length} workers - NumiCoin is now easier to mine!`);
  }

  /**
   * Stop mining and clean up workers
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
      let currentHps = 0;

      self.onmessage = function(e) {
        const { type, data } = e.data;
        
        switch (type) {
          case 'start':
            isRunning = true;
            hashesCount = 0;
            startTime = Date.now();
            startMining(data.blockNumber, data.difficulty, data.walletAddress);
            break;
          case 'stop':
            isRunning = false;
            break;
          case 'getStats':
            const now = Date.now();
            const elapsed = (now - startTime) / 1000;
            currentHps = elapsed > 0 ? Math.floor(hashesCount / elapsed) : 0;
            self.postMessage({
              type: 'stats',
              data: { hashesCount, hashesPerSecond: currentHps }
            });
            break;
        }
      };

      function startMining(blockNumber, difficulty, walletAddress) {
        const target = '0'.repeat(difficulty);
        let nonce = 0;
        
        function mine() {
          if (!isRunning) return;
          
          // Create block data
          const blockData = {
            blockNumber,
            walletAddress,
            nonce,
            timestamp: Date.now()
          };
          
          // Hash the block data
          const blockString = JSON.stringify(blockData);
          const hash = sha256Hash(blockString);
          hashesCount++;
          
          // Check if hash meets difficulty requirement
          if (hash.startsWith(target)) {
            self.postMessage({
              type: 'blockFound',
              data: {
                blockNumber,
                hash,
                nonce,
                timestamp: blockData.timestamp,
                walletAddress
              }
            });
            return;
          }
          
          nonce++;
          
          // Continue mining - faster iterations for easier mining
          setTimeout(mine, 0);
        }
        
        mine();
      }

      function sha256Hash(str) {
        // Simple SHA-256-like hash function - optimized for speed
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
   * Start monitoring mining statistics
   */
  private startStatsMonitoring(): void {
    this.statsInterval = setInterval(() => {
      // Reset stats for this interval
      this.stats.hashesPerSecond = 0;
      
      // Request stats from all workers
      this.workers.forEach(worker => {
        worker.postMessage({ type: 'getStats' });
      });

      // Notify listeners with current stats
      if (this._onStatsUpdate) {
        this._onStatsUpdate({ ...this.stats });
      }
    }, this.config.updateInterval);
  }

  /**
   * Update statistics from a worker
   */
  private updateWorkerStats(workerId: number, workerStats: any): void {
    // Update total hashes per second from all workers
    this.stats.hashesPerSecond += workerStats.hashesPerSecond;
    this.stats.totalHashes += workerStats.hashesCount;
  }

  /**
   * Handle when a block is found
   */
  private handleBlockFound(blockData: any): void {
    const result: MiningResult = {
      blockNumber: blockData.blockNumber,
      hash: blockData.hash,
      nonce: blockData.nonce,
      timestamp: blockData.timestamp,
      reward: this.config.blockReward,
      difficulty: this.config.difficulty,
    };

    // Add mining reward to wallet
    const walletAddress = this.getWalletAddress();
    addMiningReward(walletAddress, this.config.blockReward.toString());

    // Update stats
    this.stats.blocksMined++;
    this.stats.lastBlockTime = Date.now();
    this.currentBlock++;

    // Notify listeners
    if (this._onBlockMined) {
      this._onBlockMined(result);
    }

    // Start mining next block
    this.startNextBlock();
  }

  /**
   * Start mining the next block
   */
  private startNextBlock(): void {
    this.currentBlock++;
    this.stats.currentBlock = this.currentBlock;

    // Send new block data to all workers
    const blockData = {
      blockNumber: this.currentBlock,
      difficulty: this.config.difficulty,
      walletAddress: this.getWalletAddress(),
    };

    this.workers.forEach(worker => {
      worker.postMessage({ type: 'start', data: blockData });
    });
  }

  /**
   * Get the current wallet address
   */
  private getWalletAddress(): string {
    if (typeof window !== "undefined") {
      return localStorage.getItem("numi_miner_wallet_address") || "0x0000000000000000000000000000000000000000";
    }
    return "0x0000000000000000000000000000000000000000";
  }

  /**
   * Set the wallet address for mining rewards
   */
  setWalletAddress(address: string): void {
    // Store the wallet address for mining rewards
    if (typeof window !== "undefined") {
      localStorage.setItem("numi_miner_wallet_address", address);
    }
  }

  /**
   * Get current mining statistics
   */
  getStats(): MiningStats {
    return { ...this.stats };
  }

  /**
   * Set callback for stats updates
   */
  onStatsUpdate(callback: (stats: MiningStats) => void): void {
    this._onStatsUpdate = callback;
  }

  /**
   * Set callback for block mined events
   */
  onBlockMined(callback: (result: MiningResult) => void): void {
    this._onBlockMined = callback;
  }

  /**
   * Update mining configuration
   */
  updateConfig(newConfig: Partial<MiningConfig>): void {
    this.config = { ...this.config, ...newConfig };
    this.stats.difficulty = this.config.difficulty;
  }

  /**
   * Get mining configuration
   */
  getConfig(): MiningConfig {
    return { ...this.config };
  }

  /**
   * Check if mining is currently running
   */
  isMining(): boolean {
    return this.isRunning;
  }
}

// Create a singleton instance
let minerInstance: NumiMiner | null = null;

export function getMiner(): NumiMiner {
  if (!minerInstance) {
    minerInstance = new NumiMiner();
  }
  return minerInstance;
}

export function createMiner(config?: Partial<MiningConfig>): NumiMiner {
  return new NumiMiner(config);
}

// Export the class
export { NumiMiner }; 