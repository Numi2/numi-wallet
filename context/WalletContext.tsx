"use client";

import React, { createContext, useContext, useState, useEffect, ReactNode } from "react";
import { Wallet, HDNodeWallet } from "ethers";
import { 
  loadWallet, 
  loadWalletFromPhrase,
  hasWallet, 
  getBalance, 
  getTransactionHistory,
  sendTransaction,
  isValidAddress
} from "@/lib/wallet";
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

  // Fetch balance and transactions when wallet is loaded
  useEffect(() => {
    if (wallet && !isLocked) {
      refreshBalance();
      refreshTransactions();
    }
  }, [wallet, isLocked]);

  const unlock = async (password: string) => {
    setLoading(true);
    setError(undefined);
    
    try {
      const loadedWallet = loadWallet(password);
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