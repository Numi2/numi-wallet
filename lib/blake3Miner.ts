import { blake3 } from 'blake3';

export interface Blake3MiningStats {
  hashRate: number;
  totalHashes: number;
  currentBlock: number;
  difficulty: number;
  blocksMined: number;
  isMining: boolean;
}

export interface Blake3Block {
  blockNumber: number;
  previousHash: string;
  nonce: number;
  minerAddress: string;
  timestamp: number;
  hash: string;
}

export class Blake3Miner {
  private workers: Worker[] = [];
  private isMining = false;
  private stats: Blake3MiningStats;
  private onStatsUpdate?: (stats: Blake3MiningStats) => void;
  private onBlockMined?: (block: Blake3Block) => void;
  private workerCount: number;

  constructor(workerCount = 4) {
    this.workerCount = workerCount;
    this.stats = {
      hashRate: 0,
      totalHashes: 0,
      currentBlock: 1,
      difficulty: 2,
      blocksMined: 0,
      isMining: false
    };
  }

  // Blake3 hash function - quantum-safe and faster than SHA-256
  private blake3Hash(data: string): string {
    return blake3(data).toString('hex');
  }

  // Calculate mining target based on difficulty
  private getTarget(difficulty: number): string {
    // Difficulty 1 = 256 bits, Difficulty 2 = 255 bits, etc.
    const targetBits = 256 - difficulty;
    const targetHex = 'f'.repeat(Math.floor(targetBits / 4));
    return targetHex.padEnd(64, '0');
  }

  // Check if hash meets difficulty target
  private meetsDifficulty(hash: string, difficulty: number): boolean {
    const target = this.getTarget(difficulty);
    return hash < target;
  }

  // Generate block data for mining
  private generateBlockData(nonce: number, minerAddress: string): string {
    const blockData = {
      blockNumber: this.stats.currentBlock,
      previousHash: this.stats.blocksMined > 0 ? this.getPreviousHash() : '0'.repeat(64),
      nonce: nonce,
      minerAddress: minerAddress,
      timestamp: Date.now()
    };
    
    return JSON.stringify(blockData);
  }

  private getPreviousHash(): string {
    // In a real implementation, this would be stored
    return '0'.repeat(64);
  }

  // Start mining with Blake3
  async startMining(minerAddress: string): Promise<void> {
    if (this.isMining) return;

    this.isMining = true;
    this.stats.isMining = true;
    this.updateStats();

    console.log('🚀 Starting Blake3 mining with quantum-safe algorithm...');

    // Create Web Workers for parallel mining
    for (let i = 0; i < this.workerCount; i++) {
      const worker = new Worker(URL.createObjectURL(new Blob([`
        importScripts('https://cdn.jsdelivr.net/npm/blake3@2.1.4/dist/blake3.min.js');
        
        let isMining = false;
        let stats = { totalHashes: 0, hashRate: 0 };
        let startTime = Date.now();
        
        function blake3Hash(data) {
          return blake3.hash(data).toString('hex');
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
        
        function generateBlockData(nonce, minerAddress, blockNumber, previousHash) {
          const blockData = {
            blockNumber: blockNumber,
            previousHash: previousHash,
            nonce: nonce,
            minerAddress: minerAddress,
            timestamp: Date.now()
          };
          return JSON.stringify(blockData);
        }
        
        self.onmessage = function(e) {
          const { command, data } = e.data;
          
          if (command === 'start') {
            isMining = true;
            const { minerAddress, blockNumber, previousHash, difficulty } = data;
            startTime = Date.now();
            
            function mine() {
              if (!isMining) return;
              
              const nonce = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER);
              const blockData = generateBlockData(nonce, minerAddress, blockNumber, previousHash);
              const hash = blake3Hash(blockData);
              stats.totalHashes++;
              
              // Calculate hash rate
              const elapsed = (Date.now() - startTime) / 1000;
              stats.hashRate = Math.floor(stats.totalHashes / elapsed);
              
              if (meetsDifficulty(hash, difficulty)) {
                // Block found!
                self.postMessage({
                  type: 'blockFound',
                  data: {
                    blockNumber,
                    previousHash,
                    nonce,
                    minerAddress,
                    hash,
                    timestamp: Date.now()
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
      worker.postMessage({
        command: 'start',
        data: {
          minerAddress,
          blockNumber: this.stats.currentBlock,
          previousHash: this.getPreviousHash(),
          difficulty: this.stats.difficulty
        }
      });
    }
  }

  // Handle when a block is found
  private handleBlockFound(blockData: any): void {
    const block: Blake3Block = {
      blockNumber: blockData.blockNumber,
      previousHash: blockData.previousHash,
      nonce: blockData.nonce,
      minerAddress: blockData.minerAddress,
      timestamp: blockData.timestamp,
      hash: blockData.hash
    };

    console.log('🎯 Blake3 Block Found!', block);
    
    // Update stats
    this.stats.blocksMined++;
    this.stats.currentBlock++;
    
    // Adjust difficulty (simplified)
    if (this.stats.blocksMined % 10 === 0) {
      this.adjustDifficulty();
    }
    
    this.updateStats();
    
    // Notify callback
    if (this.onBlockMined) {
      this.onBlockMined(block);
    }
  }

  // Adjust mining difficulty
  private adjustDifficulty(): void {
    // Simple difficulty adjustment
    // In reality, this would be based on block time
    const targetBlockTime = 30; // 30 seconds
    const actualBlockTime = 25; // Simulated
    
    if (actualBlockTime < targetBlockTime * 0.8) {
      this.stats.difficulty++;
    } else if (actualBlockTime > targetBlockTime * 1.2) {
      this.stats.difficulty = Math.max(1, this.stats.difficulty - 1);
    }
    
    console.log(`📊 Difficulty adjusted to: ${this.stats.difficulty}`);
  }

  // Stop mining
  async stopMining(): Promise<void> {
    if (!this.isMining) return;

    this.isMining = false;
    this.stats.isMining = false;
    
    // Stop all workers
    this.workers.forEach(worker => {
      worker.postMessage({ command: 'stop' });
      worker.terminate();
    });
    
    this.workers = [];
    this.updateStats();
    
    console.log('⏹️ Blake3 mining stopped');
  }

  // Update stats and notify callback
  private updateStats(): void {
    if (this.onStatsUpdate) {
      this.onStatsUpdate({ ...this.stats });
    }
  }

  // Set callbacks
  onStatsUpdate(callback: (stats: Blake3MiningStats) => void): void {
    this.onStatsUpdate = callback;
  }

  onBlockMined(callback: (block: Blake3Block) => void): void {
    this.onBlockMined = callback;
  }

  // Get current stats
  getStats(): Blake3MiningStats {
    return { ...this.stats };
  }

  // Check if currently mining
  getIsMining(): boolean {
    return this.isMining;
  }
} 