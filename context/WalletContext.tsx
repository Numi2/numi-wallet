"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import { ethers } from "ethers";
import { createWallet, importWallet, hasWallet, getWallet, lockWallet, sendTransaction as sendTransactionLib } from "@/lib/wallet";
import { NumiBlockchain, NumiMiner } from "@/lib/numiBlockchain";

interface WalletContextType {
  // Wallet state
  isLocked: boolean;
  wallet: ethers.HDNodeWallet | null;
  address: string | null;
  balance: number;
  balanceLoading: boolean;
  
  // Mining state
  isMining: boolean;
  miningStats: {
    hashRate: number;
    totalHashes: number;
    blocksMined: number;
    currentBlock: number;
    difficulty: number;
  };
  blockchainStats: {
    totalBlocks: number;
    totalSupply: number;
    currentDifficulty: number;
    averageBlockTime: number;
    activeMiners: number;
    lastBlockTime: number;
  };
  
  // Transactions
  transactions: any[];
  
  // Session
  sessionTimeout: number;
  lastActivity: number;
  
  // Functions
  createNewWallet: () => Promise<void>;
  importExistingWallet: (recoveryPhrase: string) => Promise<void>;
  unlockWallet: (password: string) => Promise<void>;
  lockWallet: () => void;
  startMining: () => Promise<void>;
  stopMining: () => Promise<void>;
  refreshMiningStats: () => void;
  refreshBalance: () => void;
  updateSessionTimeout: (timeout: number) => void;
  sendTransaction: (toAddress: string, amount: string) => Promise<string>;
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

export const useWallet = () => {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error("useWallet must be used within a WalletProvider");
  }
  return context;
};

export const WalletProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Wallet state
  const [isLocked, setIsLocked] = useState(true);
  const [wallet, setWallet] = useState<ethers.HDNodeWallet | null>(null);
  const [address, setAddress] = useState<string | null>(null);
  const [balance, setBalance] = useState(0);
  const [balanceLoading, setBalanceLoading] = useState(false);
  
  // Mining state
  const [isMining, setIsMining] = useState(false);
  const [miningStats, setMiningStats] = useState({
    hashRate: 0,
    totalHashes: 0,
    blocksMined: 0,
    currentBlock: 0,
    difficulty: 2
  });
  const [blockchainStats, setBlockchainStats] = useState({
    totalBlocks: 1,
    totalSupply: 0,
    currentDifficulty: 2,
    averageBlockTime: 30,
    activeMiners: 0,
    lastBlockTime: Date.now()
  });
  
  // Transactions
  const [transactions, setTransactions] = useState<any[]>([]);
  
  // Session
  const [sessionTimeout, setSessionTimeout] = useState(30 * 60 * 1000); // 30 minutes
  const [lastActivity, setLastActivity] = useState(Date.now());
  
  // Blockchain and miner instances
  const [blockchain] = useState(() => new NumiBlockchain());
  const [miner, setMiner] = useState<NumiMiner | null>(null);

  // Initialize wallet on mount
  useEffect(() => {
    const initializeWallet = async () => {
      if (hasWallet()) {
        const savedWallet = getWallet();
        if (savedWallet) {
          setWallet(savedWallet);
          setAddress(savedWallet.address);
          setIsLocked(true); // Always start locked
        }
      }
    };

    initializeWallet();
  }, []);

  // Initialize blockchain callbacks
  useEffect(() => {
    blockchain.onBlockMined((block) => {
      console.log('🎉 New block mined on NumiCoin blockchain!', block);
      refreshBalance();
    });

    blockchain.onStatsUpdate((stats) => {
      setBlockchainStats(stats);
    });
  }, [blockchain]);

  // Session management
  useEffect(() => {
    const checkSession = () => {
      const now = Date.now();
      if (now - lastActivity > sessionTimeout && !isLocked) {
        lockWallet();
      }
    };

    const interval = setInterval(checkSession, 1000);
    return () => clearInterval(interval);
  }, [lastActivity, sessionTimeout, isLocked]);

  // Activity tracking
  useEffect(() => {
    const updateActivity = () => {
      setLastActivity(Date.now());
    };

    window.addEventListener('mousemove', updateActivity);
    window.addEventListener('keypress', updateActivity);
    window.addEventListener('click', updateActivity);

    return () => {
      window.removeEventListener('mousemove', updateActivity);
      window.removeEventListener('keypress', updateActivity);
      window.removeEventListener('click', updateActivity);
    };
  }, []);

  // Create new wallet
  const createNewWallet = async () => {
    try {
      const newWallet = await createWallet();
      setWallet(newWallet);
      setAddress(newWallet.address);
      setIsLocked(false);
      setLastActivity(Date.now());
      
      // Initialize miner for this wallet
      const newMiner = new NumiMiner(blockchain, newWallet.address);
      setMiner(newMiner);
      
      console.log('✅ New wallet created:', newWallet.address);
    } catch (error) {
      console.error('❌ Failed to create wallet:', error);
      throw error;
    }
  };

  // Import existing wallet
  const importExistingWallet = async (recoveryPhrase: string) => {
    try {
      const importedWallet = await importWallet(recoveryPhrase);
      setWallet(importedWallet);
      setAddress(importedWallet.address);
      setIsLocked(false);
      setLastActivity(Date.now());
      
      // Initialize miner for this wallet
      const newMiner = new NumiMiner(blockchain, importedWallet.address);
      setMiner(newMiner);
      
      console.log('✅ Wallet imported:', importedWallet.address);
    } catch (error) {
      console.error('❌ Failed to import wallet:', error);
      throw error;
    }
  };

  // Unlock wallet
  const unlockWallet = async (password: string) => {
    try {
      if (!wallet) {
        throw new Error('No wallet to unlock');
      }

      // For now, we'll use a simple password check
      // In a real implementation, you'd decrypt the wallet
      const testPassword = 'numicoin'; // Simple test password
      if (password !== testPassword) {
        throw new Error('Incorrect password');
      }

      setIsLocked(false);
      setLastActivity(Date.now());
      
      // Initialize miner if not already done
      if (!miner) {
        const newMiner = new NumiMiner(blockchain, wallet.address);
        setMiner(newMiner);
      }
      
      console.log('✅ Wallet unlocked');
    } catch (error) {
      console.error('❌ Failed to unlock wallet:', error);
      throw error;
    }
  };

  // Lock wallet
  const lockWallet = () => {
    setIsLocked(true);
    stopMining();
    console.log('🔒 Wallet locked');
  };

  // Start mining
  const startMining = async () => {
    try {
      if (!miner) {
        throw new Error('No miner available');
      }

      if (isMining) {
        console.log('⛏️ Already mining');
        return;
      }

      console.log('🚀 Starting NumiCoin mining (FREE!)...');
      
      // Set up miner callbacks
      miner.onStatsUpdate((stats) => {
        setMiningStats(stats);
      });

      miner.onBlockMined((block) => {
        console.log('🎯 Block mined!', block);
        refreshBalance();
      });

      // Start mining
      await miner.startMining();
      setIsMining(true);
      
      console.log('✅ Mining started successfully');
    } catch (error) {
      console.error('❌ Failed to start mining:', error);
      throw error;
    }
  };

  // Stop mining
  const stopMining = async () => {
    try {
      if (!miner) {
        return;
      }

      await miner.stopMining();
      setIsMining(false);
      
      console.log('⏹️ Mining stopped');
    } catch (error) {
      console.error('❌ Failed to stop mining:', error);
      throw error;
    }
  };

  // Refresh mining stats
  const refreshMiningStats = () => {
    if (miner) {
      const stats = miner.getStats();
      setMiningStats(stats);
    }
    
    const blockchainStats = blockchain.getStats();
    setBlockchainStats(blockchainStats);
  };

  // Refresh balance
  const refreshBalance = async () => {
    if (address) {
      setBalanceLoading(true);
      try {
        const balance = blockchain.getBalance(address);
        setBalance(balance);
      } catch (error) {
        console.error('Error refreshing balance:', error);
      } finally {
        setBalanceLoading(false);
      }
    }
  };

  // Update session timeout
  const updateSessionTimeout = (timeout: number) => {
    setSessionTimeout(timeout);
  };

  // Send transaction
  const sendTransaction = async (toAddress: string, amount: string): Promise<string> => {
    if (!wallet) {
      throw new Error('Wallet not available');
    }

    try {
      const txHash = await sendTransactionLib(wallet, toAddress, amount);
      // Refresh balance after successful transaction
      await refreshBalance();
      return txHash;
    } catch (error) {
      console.error('Error sending transaction:', error);
      throw error;
    }
  };

  // Auto-refresh balance when address changes
  useEffect(() => {
    if (address) {
      refreshBalance();
    }
  }, [address]);

  const value: WalletContextType = {
    // Wallet state
    isLocked,
    wallet,
    address,
    balance,
    balanceLoading,
    
    // Mining state
    isMining,
    miningStats,
    blockchainStats,
    
    // Transactions
    transactions,
    
    // Session
    sessionTimeout,
    lastActivity,
    
    // Functions
    createNewWallet,
    importExistingWallet,
    unlockWallet,
    lockWallet,
    startMining,
    stopMining,
    refreshMiningStats,
    refreshBalance,
    updateSessionTimeout,
    sendTransaction,
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
}; 