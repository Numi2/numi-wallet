"use client";

import React, { createContext, useContext, useState, useEffect, ReactNode } from "react";
import { Wallet, HDNodeWallet, ethers } from "ethers";
import { 
  loadWallet, 
  loadWalletFromPhrase,
  hasWallet, 
  getBalance, 
  getTransactionHistory,
  sendTransaction,
  isValidAddress,
  getProvider
} from "@/lib/wallet";
import { 
  ContractMiner,
  ContractMiningStats,
  MinerStats,
  PoolStats,
  PoolMinerInfo
} from "@/lib/contractMiner";
import { 
  initSessionMonitoring, 
  updateActivity, 
  clearSession,
  isSessionExpired 
} from "@/lib/session";

interface Transaction {
  hash: string;
  from: string;
  to: string;
  value: string;
  gasPrice?: string;
  gasLimit?: string;
  blockNumber?: number;
  timestamp?: number;
  type: 'sent' | 'received';
}

interface WalletContextType {
  wallet: Wallet | HDNodeWallet | null;
  loading: boolean;
  error?: string;
  balance: string;
  transactions: Transaction[];
  balanceLoading: boolean;
  transactionsLoading: boolean;
  isLocked: boolean;
  unlock: (recoveryPhrase: string) => Promise<void>;
  lock: () => void;
  clearError: () => void;
  refreshBalance: () => Promise<void>;
  refreshTransactions: () => Promise<void>;
  sendTransaction: (toAddress: string, amount: string) => Promise<string>;
  // Mining functionality
  miningStats: ContractMiningStats;
  minerStats: MinerStats | null;
  poolStats: PoolStats | null;
  poolMinerInfo: PoolMinerInfo | null;
  startMining: () => Promise<void>;
  stopMining: () => void;
  isMining: () => boolean;
  joinPool: (amount: string) => Promise<void>;
  leavePool: () => Promise<void>;
  claimPoolRewards: () => Promise<void>;
  refreshMiningStats: () => Promise<void>;
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

interface WalletProviderProps {
  children: ReactNode;
}

export function WalletProvider({ children }: WalletProviderProps) {
  const [wallet, setWallet] = useState<Wallet | HDNodeWallet | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | undefined>(undefined);
  const [balance, setBalance] = useState<string>("0");
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [balanceLoading, setBalanceLoading] = useState(false);
  const [transactionsLoading, setTransactionsLoading] = useState(false);
  const [isLocked, setIsLocked] = useState(true);
  const [miningStats, setMiningStats] = useState<ContractMiningStats>({
    currentBlock: 1,
    difficulty: 4,
    blockReward: "0",
    lastMineTime: 0,
    targetMineTime: 600,
    hashesPerSecond: 0,
    totalHashes: 0,
    isMining: false,
  });
  const [minerStats, setMinerStats] = useState<MinerStats | null>(null);
  const [poolStats, setPoolStats] = useState<PoolStats | null>(null);
  const [poolMinerInfo, setPoolMinerInfo] = useState<PoolMinerInfo | null>(null);
  const [contractMiner, setContractMiner] = useState<ContractMiner | null>(null);

  // Check if wallet exists on mount
  useEffect(() => {
    const walletExists = hasWallet();
    if (!walletExists) {
      setWallet(null);
      setIsLocked(true);
    } else {
      // Check if session is expired
      if (isSessionExpired()) {
        setIsLocked(true);
        setWallet(null);
      } else {
        setIsLocked(false);
      }
    }
  }, []);

  // Initialize session monitoring
  useEffect(() => {
    if (wallet) {
      const cleanup = initSessionMonitoring(() => {
        // Auto-lock when session expires
        lock();
      });

      return cleanup;
    }
  }, [wallet]);

  // Initialize mining functionality - temporarily disabled for deployment
  // useEffect(() => {
  //   if (wallet && !isLocked) {
  //     const numiCoinAddress = process.env.NEXT_PUBLIC_NUMICOIN_ADDRESS;
  //     const miningPoolAddress = process.env.NEXT_PUBLIC_MINING_POOL_ADDRESS;
  //     
  //     if (numiCoinAddress && miningPoolAddress) {
  //       try {
  //         const provider = getProvider();
  //         const miner = new ContractMiner(numiCoinAddress, miningPoolAddress, provider);
  //         miner.setWallet(wallet as ethers.Wallet);
  //         
  //         // Set up mining callbacks
  //         miner.onStatsUpdate((stats) => {
  //           setMiningStats(stats);
  //         });
  //         
  //         miner.onBlockMined((result) => {
  //           console.log("Block mined!", result);
  //           // Refresh balance after mining reward
  //           setTimeout(() => {
  //             refreshBalance();
  //             refreshMiningStats();
  //           }, 1000);
  //         });
  //         
  //         setContractMiner(miner);
  //         
  //         // Load initial stats
  //         refreshMiningStats();
  //       } catch (error) {
  //         console.error("Failed to initialize mining:", error);
  //       }
  //     }
  //   }
  // }, [wallet, isLocked]);

  // Fetch balance and transactions when wallet is loaded
  useEffect(() => {
    if (wallet && !isLocked) {
      refreshBalance();
      refreshTransactions();
    }
  }, [wallet, isLocked]);

  const unlock = async (recoveryPhrase: string) => {
    setLoading(true);
    setError(undefined);
    
    try {
      const loadedWallet = loadWalletFromPhrase(recoveryPhrase);
      setWallet(loadedWallet);
      setIsLocked(false);
      updateActivity(); // Update session activity
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to unlock wallet";
      setError(errorMessage);
      setWallet(null);
      setIsLocked(true);
    } finally {
      setLoading(false);
    }
  };

  const lock = () => {
    setWallet(null);
    setIsLocked(true);
    clearSession();
    setBalance("0");
    setTransactions([]);
    clearError();
  };

  const clearError = () => {
    setError(undefined);
  };

  const refreshBalance = async () => {
    if (!wallet || isLocked) return;
    
    setBalanceLoading(true);
    try {
      const walletBalance = await getBalance(wallet.address);
      setBalance(walletBalance);
      updateActivity(); // Update session activity
    } catch (err) {
      console.error("Error refreshing balance:", err);
      setError("Failed to refresh balance");
    } finally {
      setBalanceLoading(false);
    }
  };

  const refreshTransactions = async () => {
    if (!wallet || isLocked) return;
    
    setTransactionsLoading(true);
    try {
      const walletTransactions = await getTransactionHistory(wallet.address, 20);
      setTransactions(walletTransactions);
      updateActivity(); // Update session activity
    } catch (err) {
      console.error("Error refreshing transactions:", err);
      setError("Failed to refresh transactions");
    } finally {
      setTransactionsLoading(false);
    }
  };

  const handleSendTransaction = async (toAddress: string, amount: string): Promise<string> => {
    if (!wallet || isLocked) {
      throw new Error("Wallet not loaded or locked");
    }

    if (!isValidAddress(toAddress)) {
      throw new Error("Invalid recipient address");
    }

    if (parseFloat(amount) <= 0) {
      throw new Error("Amount must be greater than 0");
    }

    if (parseFloat(amount) > parseFloat(balance)) {
      throw new Error("Insufficient balance");
    }

    try {
      const txHash = await sendTransaction(wallet as HDNodeWallet, toAddress, amount);
      updateActivity(); // Update session activity
      
      // Refresh balance and transactions after successful send
      setTimeout(() => {
        refreshBalance();
        refreshTransactions();
      }, 2000); // Wait a bit for transaction to be processed
      
      return txHash;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to send transaction";
      throw new Error(errorMessage);
    }
  };

  // Mining functions
  const handleStartMining = async (): Promise<void> => {
    if (!wallet || isLocked || !contractMiner) {
      throw new Error("Wallet not loaded or mining not initialized");
    }

    try {
      await contractMiner.startMining();
      updateActivity(); // Update session activity
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to start mining";
      throw new Error(errorMessage);
    }
  };

  const handleStopMining = (): void => {
    if (contractMiner) {
      contractMiner.stopMining();
    }
  };

  const handleIsMining = (): boolean => {
    return contractMiner ? contractMiner.isMining() : false;
  };

  const handleJoinPool = async (amount: string): Promise<void> => {
    if (!wallet || isLocked || !contractMiner) {
      throw new Error("Wallet not loaded or mining not initialized");
    }

    try {
      await contractMiner.joinPool(amount);
      await handleRefreshMiningStats();
      updateActivity();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to join pool";
      throw new Error(errorMessage);
    }
  };

  const handleLeavePool = async (): Promise<void> => {
    if (!wallet || isLocked || !contractMiner) {
      throw new Error("Wallet not loaded or mining not initialized");
    }

    try {
      await contractMiner.leavePool();
      await handleRefreshMiningStats();
      updateActivity();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to leave pool";
      throw new Error(errorMessage);
    }
  };

  const handleClaimPoolRewards = async (): Promise<void> => {
    if (!wallet || isLocked || !contractMiner) {
      throw new Error("Wallet not loaded or mining not initialized");
    }

    try {
      await contractMiner.claimPoolRewards();
      await handleRefreshMiningStats();
      updateActivity();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to claim rewards";
      throw new Error(errorMessage);
    }
  };

  const handleRefreshMiningStats = async (): Promise<void> => {
    if (!wallet || isLocked || !contractMiner) return;

    try {
      const [miningStats, minerStats, poolStats, poolMinerInfo] = await Promise.all([
        contractMiner.getMiningStats(),
        contractMiner.getMinerStats(wallet.address),
        contractMiner.getPoolStats(),
        contractMiner.getPoolMinerInfo(wallet.address)
      ]);

      setMiningStats(miningStats);
      setMinerStats(minerStats);
      setPoolStats(poolStats);
      setPoolMinerInfo(poolMinerInfo);
    } catch (err) {
      console.error("Failed to refresh mining stats:", err);
    }
  };

  const value: WalletContextType = {
    wallet,
    loading,
    error,
    balance,
    transactions,
    balanceLoading,
    transactionsLoading,
    isLocked,
    unlock,
    lock,
    clearError,
    refreshBalance,
    refreshTransactions,
    sendTransaction: handleSendTransaction,
    // Mining functionality
    miningStats,
    minerStats,
    poolStats,
    poolMinerInfo,
    startMining: handleStartMining,
    stopMining: handleStopMining,
    isMining: handleIsMining,
    joinPool: handleJoinPool,
    leavePool: handleLeavePool,
    claimPoolRewards: handleClaimPoolRewards,
    refreshMiningStats: handleRefreshMiningStats,
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
}

export function useWallet() {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error("useWallet must be used within a WalletProvider");
  }
  return context;
} 