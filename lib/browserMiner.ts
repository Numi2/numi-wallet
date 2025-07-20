import { ethers } from "ethers";

export interface BrowserMiningStats {
  currentBlock: number;
  difficulty: number;
  blockReward: string;
  lastMineTime: number;
  targetMineTime: number;
  hashesPerSecond: number;
  totalHashes: number;
  isMining: boolean;
  blocksMined: number;
}

export interface BrowserMinerConfig {
  difficulty: number;
  blockReward: number;
  maxWorkers: number;
  updateInterval: number;
}

class BrowserMiner {
  private isRunning: boolean = false;
  private workers: Worker[] = [];
  private stats: BrowserMiningStats;
  private _onStatsUpdate?: (stats: BrowserMiningStats) => void;
  private _onBlockMined?: (result: any) => void;
  private statsInterval?: NodeJS.Timeout;
  private config: BrowserMinerConfig;
  private blocksMined: number = 0;
  private startTime: number = 0;

  constructor(config: BrowserMinerConfig = {
    difficulty: 2,
    blockReward: 0.005,
    maxWorkers: 4,
    updateInterval: 500
  }) {
    this.config = config;
    this.stats = {
      currentBlock: 1,
      difficulty: config.difficulty,
      blockReward: config.blockReward.toString(),
      lastMineTime: 0,
      targetMineTime: 600,
      hashesPerSecond: 0,
      totalHashes: 0,
      isMining: false,
      blocksMined: 0
    };
  }

  /**
   * Start mining with browser workers
   */
  async startMining(): Promise<void> {
    if (this.isRunning) {
      throw new Error("Mining is already running");
    }

    this.isRunning = true;
    this.stats.isMining = true;
    this.startTime = Date.now();
    this.blocksMined = 0;

    // Create Web Workers for mining
    for (let i = 0; i < this.config.maxWorkers; i++) {
      const worker = this.createMiningWorker(i);
      this.workers.push(worker);
    }

    // Start stats monitoring
    this.startStatsMonitoring();

    console.log(`Started browser mining with ${this.workers.length} workers`);
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

    console.log("Browser mining stopped");
  }

  /**
   * Create a Web Worker for mining
   */
  private createMiningWorker(workerId: number): Worker {
    const workerCode = `
      let hashesCount = 0;
      let startTime = Date.now();
      let isRunning = false;
      let currentDifficulty = ${this.config.difficulty};
      let currentBlock = 1;

      // Simple hash function for demonstration
      function simpleHash(input) {
        let hash = 0;
        for (let i = 0; i < input.length; i++) {
          const char = input.charCodeAt(i);
          hash = ((hash << 5) - hash) + char;
          hash = hash & hash; // Convert to 32-bit integer
        }
        return Math.abs(hash).toString(16);
      }

      // Check if hash meets difficulty requirement
      function meetsDifficulty(hash, difficulty) {
        const zeros = '0'.repeat(difficulty);
        return hash.startsWith(zeros);
      }

      function startMining() {
        while (isRunning) {
          const nonce = Math.floor(Math.random() * 1000000);
          const blockData = \`block\${currentBlock}nonce\${nonce}\${Date.now()}\`;
          const hash = simpleHash(blockData);
          
          hashesCount++;
          
          if (meetsDifficulty(hash, currentDifficulty)) {
            self.postMessage({
              type: 'blockFound',
              data: {
                blockNumber: currentBlock,
                nonce: nonce,
                hash: hash,
                blockData: blockData,
                workerId: ${workerId}
              }
            });
            currentBlock++;
          }
          
          // Send stats every 1000 hashes
          if (hashesCount % 1000 === 0) {
            const now = Date.now();
            const elapsed = (now - startTime) / 1000;
            const hps = elapsed > 0 ? Math.floor(hashesCount / elapsed) : 0;
            
            self.postMessage({
              type: 'stats',
              data: {
                workerId: ${workerId},
                hashesPerSecond: hps,
                totalHashes: hashesCount,
                elapsed: elapsed
              }
            });
          }
        }
      }

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
              data: {
                workerId: ${workerId},
                hashesPerSecond: hps,
                totalHashes: hashesCount,
                elapsed: elapsed
              }
            });
            break;
        }
      };
    `;

    const blob = new Blob([workerCode], { type: 'application/javascript' });
    const worker = new Worker(URL.createObjectURL(blob));

    worker.onmessage = (e) => {
      const { type, data } = e.data;
      
      switch (type) {
        case 'blockFound':
          this.handleBlockFound(data);
          break;
        case 'stats':
          this.updateWorkerStats(workerId, data);
          break;
      }
    };

    // Start the worker
    worker.postMessage({
      type: 'start',
      data: {
        difficulty: this.config.difficulty,
        blockNumber: this.stats.currentBlock
      }
    });

    return worker;
  }

  /**
   * Handle when a block is found
   */
  private handleBlockFound(blockData: any): void {
    this.blocksMined++;
    this.stats.currentBlock++;
    this.stats.lastMineTime = Date.now();
    this.stats.blocksMined = this.blocksMined;

    console.log("Block mined!", blockData);

    // Call the callback
    if (this._onBlockMined) {
      this._onBlockMined({
        blockNumber: blockData.blockNumber,
        hash: blockData.hash,
        nonce: blockData.nonce,
        reward: this.config.blockReward,
        timestamp: Date.now()
      });
    }

    // Update difficulty based on mining speed
    const timeSinceLastBlock = this.stats.lastMineTime - this.startTime;
    if (this.blocksMined > 0) {
      const avgTimePerBlock = timeSinceLastBlock / this.blocksMined;
      if (avgTimePerBlock < this.stats.targetMineTime * 0.5) {
        this.stats.difficulty = Math.min(this.stats.difficulty + 1, 6);
      } else if (avgTimePerBlock > this.stats.targetMineTime * 2) {
        this.stats.difficulty = Math.max(this.stats.difficulty - 1, 1);
      }
    }

    // Update workers with new difficulty
    this.workers.forEach(worker => {
      worker.postMessage({
        type: 'updateDifficulty',
        data: { difficulty: this.stats.difficulty }
      });
    });
  }

  /**
   * Update worker statistics
   */
  private updateWorkerStats(workerId: number, workerStats: any): void {
    // Aggregate stats from all workers
    let totalHps = 0;
    let totalHashes = 0;

    // This is a simplified version - in a real implementation you'd track per-worker stats
    this.stats.hashesPerSecond = workerStats.hashesPerSecond;
    this.stats.totalHashes = workerStats.totalHashes;
  }

  /**
   * Start stats monitoring
   */
  private startStatsMonitoring(): void {
    this.statsInterval = setInterval(() => {
      // Update stats
      if (this._onStatsUpdate) {
        this._onStatsUpdate(this.stats);
      }
    }, this.config.updateInterval);
  }

  /**
   * Get current mining stats
   */
  getMiningStats(): BrowserMiningStats {
    return { ...this.stats };
  }

  /**
   * Set up stats update callback
   */
  onStatsUpdate(callback: (stats: BrowserMiningStats) => void): void {
    this._onStatsUpdate = callback;
  }

  /**
   * Set up block mined callback
   */
  onBlockMined(callback: (result: any) => void): void {
    this._onBlockMined = callback;
  }

  /**
   * Check if mining is currently running
   */
  isMining(): boolean {
    return this.isRunning;
  }
}

export { BrowserMiner }; 