import { blake3 } from "@noble/hashes/blake3";
import { bytesToHex } from "@noble/hashes/utils";

export interface NumiBlock {
  index: number;
  timestamp: number;
  data: {
    minerAddress: string;
    nonce: number;
    reward: number;
  };
  previousHash: string;
  hash: string;
  difficulty: number;
}

export interface NumiBlockchainStats {
  totalBlocks: number;
  totalSupply: number;
  currentDifficulty: number;
  averageBlockTime: number;
  activeMiners: number;
  lastBlockTime: number;
}

export interface MiningStats {
  hashRate: number;
  totalHashes: number;
  blocksMined: number;
  currentBlock: number;
  difficulty: number;
  isMining: boolean;
}

export class NumiBlockchain {
  private chain: NumiBlock[] = [];
  private pendingTransactions: any[] = [];
  private miningNodes: Set<string> = new Set();
  private stats: NumiBlockchainStats;
  private _onBlockMined?: (block: NumiBlock) => void;
  private _onStatsUpdate?: (stats: NumiBlockchainStats) => void;

  constructor() {
    // Create genesis block
    this.createGenesisBlock();
    
    this.stats = {
      totalBlocks: 1,
      totalSupply: 0,
      currentDifficulty: 2,
      averageBlockTime: 30,
      activeMiners: 0,
      lastBlockTime: Date.now()
    };
  }

  // Create the first block (genesis)
  private createGenesisBlock(): void {
    const genesisBlock: NumiBlock = {
      index: 0,
      timestamp: Date.now(),
      data: {
        minerAddress: '0x0000000000000000000000000000000000000000',
        nonce: 0,
        reward: 0
      },
      previousHash: '0',
      hash: this.calculateHash(0, Date.now(), { minerAddress: '0x0', nonce: 0, reward: 0 }, '0', 2),
      difficulty: 2
    };
    
    this.chain.push(genesisBlock);
  }

  // Calculate block hash using Blake3 (quantum-safe and fast)
  private calculateHash(index: number, timestamp: number, data: any, previousHash: string, difficulty: number): string {
    const blockData = JSON.stringify({
      index,
      timestamp,
      data,
      previousHash,
      difficulty
    });
    
    const hash = blake3(blockData);
    return bytesToHex(hash);
  }

  // Get the latest block
  getLatestBlock(): NumiBlock {
    return this.chain[this.chain.length - 1];
  }

  // Add a new block to the chain
  addBlock(newBlock: NumiBlock): boolean {
    // Verify the block
    if (!this.isValidBlock(newBlock)) {
      console.log('❌ Invalid block rejected');
      return false;
    }

    // Add block to chain
    this.chain.push(newBlock);
    
    // Update stats
    this.stats.totalBlocks++;
    this.stats.totalSupply += newBlock.data.reward;
    this.stats.lastBlockTime = newBlock.timestamp;
    
    // Adjust difficulty
    this.adjustDifficulty();
    
    // Update average block time
    this.updateAverageBlockTime();
    
    // Notify listeners
    if (this._onBlockMined) {
      this._onBlockMined(newBlock);
    }
    
    if (this._onStatsUpdate) {
      this._onStatsUpdate({ ...this.stats });
    }
    
    console.log(`✅ Block ${newBlock.index} added to chain`);
    console.log(`💰 Miner ${newBlock.data.minerAddress} earned ${newBlock.data.reward} NUMI`);
    
    return true;
  }

  // Verify if a block is valid
  private isValidBlock(block: NumiBlock): boolean {
    const previousBlock = this.getLatestBlock();
    
    // Check if block index is correct
    if (block.index !== previousBlock.index + 1) {
      return false;
    }
    
    // Check if previous hash is correct
    if (block.previousHash !== previousBlock.hash) {
      return false;
    }
    
    // Check if hash is valid
    const calculatedHash = this.calculateHash(
      block.index,
      block.timestamp,
      block.data,
      block.previousHash,
      block.difficulty
    );
    
    if (block.hash !== calculatedHash) {
      return false;
    }
    
    // Check if hash meets difficulty requirement
    if (!this.meetsDifficulty(block.hash, block.difficulty)) {
      return false;
    }
    
    return true;
  }

  // Check if hash meets difficulty target
  private meetsDifficulty(hash: string, difficulty: number): boolean {
    const targetBits = 256 - difficulty;
    const targetHex = 'f'.repeat(Math.floor(targetBits / 4));
    const target = targetHex.padEnd(64, '0');
    return hash < target;
  }

  // Adjust mining difficulty based on block time
  private adjustDifficulty(): void {
    const targetBlockTime = 30; // 30 seconds
    const recentBlocks = this.chain.slice(-10);
    
    if (recentBlocks.length < 2) return;
    
    const averageBlockTime = (recentBlocks[recentBlocks.length - 1].timestamp - recentBlocks[0].timestamp) / (recentBlocks.length - 1) / 1000;
    
    if (averageBlockTime < targetBlockTime * 0.8) {
      this.stats.currentDifficulty++;
      console.log(`📈 Difficulty increased to ${this.stats.currentDifficulty}`);
    } else if (averageBlockTime > targetBlockTime * 1.2) {
      this.stats.currentDifficulty = Math.max(1, this.stats.currentDifficulty - 1);
      console.log(`📉 Difficulty decreased to ${this.stats.currentDifficulty}`);
    }
  }

  // Update average block time
  private updateAverageBlockTime(): void {
    const recentBlocks = this.chain.slice(-20);
    if (recentBlocks.length >= 2) {
      const totalTime = (recentBlocks[recentBlocks.length - 1].timestamp - recentBlocks[0].timestamp) / 1000;
      this.stats.averageBlockTime = totalTime / (recentBlocks.length - 1);
    }
    if (this._onStatsUpdate) {
      this._onStatsUpdate(this.stats);
    }
  }

  // Register a mining node
  registerMiner(minerAddress: string): void {
    this.miningNodes.add(minerAddress);
    this.stats.activeMiners = this.miningNodes.size;
    console.log(`👷 Miner ${minerAddress} registered`);
  }

  // Unregister a mining node
  unregisterMiner(minerAddress: string): void {
    this.miningNodes.delete(minerAddress);
    this.stats.activeMiners = this.miningNodes.size;
    console.log(`👷 Miner ${minerAddress} unregistered`);
  }

  // Get current difficulty
  getCurrentDifficulty(): number {
    return this.stats.currentDifficulty;
  }

  // Get blockchain stats
  getStats(): NumiBlockchainStats {
    return { ...this.stats };
  }

  // Get the entire chain
  getChain(): NumiBlock[] {
    return [...this.chain];
  }

  // Get balance for an address
  getBalance(address: string): number {
    let balance = 0;
    
    for (const block of this.chain) {
      if (block.data.minerAddress === address) {
        balance += block.data.reward;
      }
    }
    
    return balance;
  }

  // Set callbacks
  onBlockMined(callback: (block: NumiBlock) => void): void {
    this._onBlockMined = callback;
  }

  onStatsUpdate(callback: (stats: NumiBlockchainStats) => void): void {
    this._onStatsUpdate = callback;
  }

  // Validate the entire chain
  isChainValid(): boolean {
    for (let i = 1; i < this.chain.length; i++) {
      const currentBlock = this.chain[i];
      const previousBlock = this.chain[i - 1];
      
      if (!this.isValidBlock(currentBlock)) {
        return false;
      }
    }
    
    return true;
  }
}

export class NumiMiner {
  private blockchain: NumiBlockchain;
  private workers: Worker[] = [];
  private isMining = false;
  private stats: MiningStats;
  private minerAddress: string;
  private _onStatsUpdate?: (stats: MiningStats) => void;
  private _onBlockMined?: (block: NumiBlock) => void;
  private workerCount: number;

  constructor(blockchain: NumiBlockchain, minerAddress: string, workerCount = 4) {
    this.blockchain = blockchain;
    this.minerAddress = minerAddress;
    this.workerCount = workerCount;
    
    this.stats = {
      hashRate: 0,
      totalHashes: 0,
      blocksMined: 0,
      currentBlock: 0,
      difficulty: 2,
      isMining: false
    };
  }

  // Start mining
  async startMining(): Promise<void> {
    if (this.isMining) return;

    this.isMining = true;
    this.stats.isMining = true;
    this.blockchain.registerMiner(this.minerAddress);
    
    console.log('🚀 Starting NumiCoin mining (FREE!)...');

    // Create Web Workers for parallel mining
    for (let i = 0; i < this.workerCount; i++) {
      const worker = new Worker(URL.createObjectURL(new Blob([`
        // Note: Web Workers can't import ES modules, so we'll try to load a standalone UMD build of @noble/hashes/blake3
        importScripts('https://cdn.jsdelivr.net/npm/@noble/hashes@1.3.0/blake3.min.js');
        
        let isMining = false;
        let stats = { totalHashes: 0, hashRate: 0 };
        let startTime = Date.now();

        // Helper: convert Uint8Array -> hex string
        function bytesToHex(bytes) {
          let hex = '';
          for (let i = 0; i < bytes.length; i++) {
            const byteHex = bytes[i].toString(16).padStart(2, '0');
            hex += byteHex;
          }
          return hex;
        }

        function blake3HashHex(str) {
          // Convert string to Uint8Array (UTF-8)
          const encoder = new TextEncoder();
          const data = encoder.encode(str);
          // globalThis.blake3 is exposed by the imported script
          const digest = globalThis.blake3(data);
          return bytesToHex(digest);
        }
        
        function getTarget(difficulty) {
          const targetBits = 256 - difficulty;
          const targetHex = 'f'.repeat(Math.floor(targetBits / 4));
          return targetHex.padEnd(64, '0');
        }
        
        function meetsDifficulty(hash, difficulty) {
          const target = getTarget(difficulty);
          return hash < target;
        }
        
        function calculateHash(index, timestamp, data, previousHash, difficulty) {
          const blockData = JSON.stringify({
            index,
            timestamp,
            data,
            previousHash,
            difficulty
          });
          return blake3HashHex(blockData);
        }
        
        self.onmessage = function(e) {
          const { command, data } = e.data;
          
          if (command === 'start') {
            isMining = true;
            const { minerAddress, currentBlock, previousHash, difficulty } = data;
            startTime = Date.now();
            
            function mine() {
              if (!isMining) return;
              
              const nonce = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER);
              const timestamp = Date.now();
              const blockData = {
                minerAddress: minerAddress,
                nonce: nonce,
                reward: 0.005 // 0.005 NUMI per block
              };
              
              const hash = calculateHash(currentBlock, timestamp, blockData, previousHash, difficulty);
              stats.totalHashes++;
              
              // Calculate hash rate
              const elapsed = (Date.now() - startTime) / 1000;
              stats.hashRate = Math.floor(stats.totalHashes / elapsed);
              
              if (meetsDifficulty(hash, difficulty)) {
                // Block found!
                self.postMessage({
                  type: 'blockFound',
                  data: {
                    index: currentBlock,
                    timestamp: timestamp,
                    data: blockData,
                    previousHash: previousHash,
                    hash: hash,
                    difficulty: difficulty
                  }
                });
                return;
              }
              
              // Report stats every 1000 hashes
              if (stats.totalHashes % 1000 === 0) {
                self.postMessage({
                  type: 'stats',
                  data: { ...stats }
                });
              }
              
              // Continue mining
              setTimeout(mine, 0);
            }
            
            mine();
          }
          
          if (command === 'stop') {
            isMining = false;
          }
          
          if (command === 'updateDifficulty') {
            // Update difficulty for next mining session
          }
        };
      `], { type: 'application/javascript' })));

      worker.onmessage = (e) => {
        const { type, data } = e.data;
        
        if (type === 'stats') {
          this.stats.hashRate = data.hashRate;
          this.stats.totalHashes += data.totalHashes;
          this.updateStats();
        }
        
        if (type === 'blockFound') {
          this.handleBlockFound(data);
        }
      };

      this.workers.push(worker);
      
      // Start mining in this worker
      const latestBlock = this.blockchain.getLatestBlock();
      worker.postMessage({
        command: 'start',
        data: {
          minerAddress: this.minerAddress,
          currentBlock: latestBlock.index + 1,
          previousHash: latestBlock.hash,
          difficulty: this.blockchain.getCurrentDifficulty()
        }
      });
    }
  }

  // Handle when a block is found
  private handleBlockFound(blockData: any): void {
    const block: NumiBlock = {
      index: blockData.index,
      timestamp: blockData.timestamp,
      data: blockData.data,
      previousHash: blockData.previousHash,
      hash: blockData.hash,
      difficulty: blockData.difficulty
    };

    console.log('🎯 NumiCoin Block Found!', block);
    
    // Add block to blockchain
    const success = this.blockchain.addBlock(block);
    
    if (success) {
      // Update stats
      this.stats.blocksMined++;
      this.stats.currentBlock = block.index;
      
      // Restart mining for next block
      this.restartMining();
    }
    
    // Notify callback
    if (this._onBlockMined) {
      this._onBlockMined(block);
    }
  }

  // Restart mining for next block
  private restartMining(): void {
    // Stop current workers
    this.workers.forEach(worker => {
      worker.postMessage({ command: 'stop' });
      worker.terminate();
    });
    
    this.workers = [];
    
    // Start mining again
    setTimeout(() => {
      if (this.isMining) {
        this.startMining();
      }
    }, 100);
  }

  // Stop mining
  async stopMining(): Promise<void> {
    if (!this.isMining) return;

    this.isMining = false;
    this.stats.isMining = false;
    this.blockchain.unregisterMiner(this.minerAddress);
    
    // Stop all workers
    this.workers.forEach(worker => {
      worker.postMessage({ command: 'stop' });
      worker.terminate();
    });
    
    this.workers = [];
    this.updateStats();
    
    console.log('⏹️ NumiCoin mining stopped');
  }

  // Update stats and notify listeners
  private updateStats(): void {
    if (this._onStatsUpdate) {
      this._onStatsUpdate(this.stats);
    }
  }

  // Set callbacks
  onStatsUpdate(callback: (stats: MiningStats) => void): void {
    this._onStatsUpdate = callback;
  }

  onBlockMined(callback: (block: NumiBlock) => void): void {
    this._onBlockMined = callback;
  }

  // Get current stats
  getStats(): MiningStats {
    return { ...this.stats };
  }

  // Check if currently mining
  getIsMining(): boolean {
    return this.isMining;
  }
} 