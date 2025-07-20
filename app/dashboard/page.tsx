"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet, formatAddress } from "@/lib/wallet";

export default function DashboardPage() {
  const { 
    wallet, 
    loading, 
    error, 
    unlock, 
    lock,
    clearError,
    balance,
    transactions,
    balanceLoading,
    transactionsLoading,
    isLocked,
    refreshBalance,
    refreshTransactions
  } = useWallet();
  const [password, setPassword] = useState("");
  const router = useRouter();

  useEffect(() => {
    // Check if wallet exists, if not redirect to onboarding
    if (!hasWallet()) {
      router.push("/onboarding");
    }
  }, [router]);



  const handleUnlock = async (e: React.FormEvent) => {
    e.preventDefault();
    await unlock(password);
  };

  const handleLogout = () => {
    lock();
    setPassword("");
    router.push("/login");
  };

  const copyAddress = async () => {
    if (wallet?.address) {
      try {
        await navigator.clipboard.writeText(wallet.address);
        // You could add a toast notification here
      } catch (err) {
        console.error("Failed to copy address:", err);
      }
    }
  };

  const formatTransactionValue = (value: string) => {
    const numValue = parseFloat(value);
    if (numValue === 0) return "0 ETH";
    if (numValue < 0.001) return `${numValue.toFixed(6)} ETH`;
    return `${numValue.toFixed(4)} ETH`;
  };

  const getTransactionStatus = (tx: any) => {
    if (tx.blockNumber) {
      return tx.status === 1 ? "Confirmed" : "Failed";
    }
    return "Pending";
  };

  if (isLocked) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
        <div className="w-full max-w-md">
          <div className="glass-card text-center">
            <div className="mb-8">
              <h1 className="text-3xl font-bold gradient-text mb-2">Welcome Back</h1>
              <p className="text-white/80">Unlock your wallet to continue</p>
            </div>

            <form onSubmit={handleUnlock} className="space-y-6">
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-white/90 mb-2">
                  Password
                </label>
                <input
                  type="password"
                  id="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="glass-input w-full touch-target"
                  placeholder="Enter your password"
                  disabled={loading}
                />
              </div>

              {error && (
                <div className="glass-card bg-red-500/20 border-red-500/30 text-red-200">
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={loading || !password}
                className="glass-button w-full touch-target disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? "Unlocking..." : "Unlock Wallet"}
              </button>
            </form>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-4xl mx-auto space-y-6">
        {/* Header Card */}
        <div className="glass-card">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold gradient-text">Dashboard</h1>
              <p className="text-white/70 mt-1">Manage your cryptocurrency</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={refreshBalance}
                disabled={balanceLoading}
                className="glass-button-secondary touch-target text-sm"
              >
                {balanceLoading ? "Refreshing..." : "Refresh"}
              </button>
              <button
                onClick={handleLogout}
                className="glass-button-danger touch-target text-sm"
              >
                Lock Wallet
              </button>
            </div>
          </div>
        </div>

        {/* Balance & Address Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="glass-card">
            <h3 className="text-lg font-semibold text-white/90 mb-4">Wallet Address</h3>
            <div className="flex items-center justify-between">
              <p className="text-sm font-mono text-white/80 break-all">
                {wallet?.address}
              </p>
              <button
                onClick={copyAddress}
                className="glass-button-secondary touch-target text-sm ml-2 flex-shrink-0"
              >
                Copy
              </button>
            </div>
          </div>

          <div className="glass-card">
            <h3 className="text-lg font-semibold text-white/90 mb-4">Balance</h3>
            <div className="flex items-center justify-between">
              <p className="text-3xl font-bold gradient-text">
                {balanceLoading ? (
                  <span className="loading-shimmer">Loading...</span>
                ) : (
                  `${parseFloat(balance).toFixed(6)} ETH`
                )}
              </p>
              <div className="w-8 h-8 float"></div>
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Quick Actions</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button 
              onClick={() => router.push("/send")}
              className="glass-button touch-target h-16 flex items-center justify-center"
            >
              <span className="text-lg">Send</span>
            </button>
            <button 
              onClick={() => router.push("/receive")}
              className="glass-button touch-target h-16 flex items-center justify-center"
            >
              <span className="text-lg">Receive</span>
            </button>
            <button className="glass-button-secondary touch-target h-16 flex items-center justify-center">
              <span className="text-lg">Swap</span>
            </button>
          </div>
        </div>

        {/* Transaction History */}
        <div className="glass-card">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-6">
            <h2 className="text-xl font-bold gradient-text">Transaction History</h2>
            <button
              onClick={refreshTransactions}
              disabled={transactionsLoading}
              className="glass-button-secondary touch-target text-sm"
            >
              {transactionsLoading ? "Refreshing..." : "Refresh"}
            </button>
          </div>

          {transactionsLoading ? (
            <div className="text-center py-12">
              <div className="w-12 h-12 border-4 border-white/20 border-t-white/60 rounded-full animate-spin mx-auto mb-4"></div>
              <p className="text-white/70">Loading transactions...</p>
            </div>
          ) : transactions.length === 0 ? (
            <div className="text-center py-12">
              <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                <span className="text-2xl">📊</span>
              </div>
              <p className="text-white/70 text-lg mb-2">No transactions yet</p>
              <p className="text-white/50">Your transaction history will appear here</p>
            </div>
          ) : (
            <div className="space-y-4 max-h-96 overflow-y-auto">
              {transactions.map((tx, index) => (
                <div key={tx.hash || index} className="glass-card bg-white/5 hover:bg-white/10 transition-all duration-200">
                  <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-3">
                        <span className={`px-3 py-1 rounded-full text-xs font-medium ${
                          tx.type === 'sent' 
                            ? 'bg-red-500/20 text-red-300 border border-red-500/30' 
                            : 'bg-green-500/20 text-green-300 border border-green-500/30'
                        }`}>
                          {tx.type === 'sent' ? 'Sent' : 'Received'}
                        </span>
                        <span className="text-xs text-white/50 px-2 py-1 glass-card">
                          {getTransactionStatus(tx)}
                        </span>
                      </div>
                      
                      <div className="space-y-2">
                        <p className="text-sm">
                          <span className="text-white/60">To:</span>{' '}
                          <span className="font-mono text-white/80">{formatAddress(tx.to)}</span>
                        </p>
                        <p className="text-sm">
                          <span className="text-white/60">From:</span>{' '}
                          <span className="font-mono text-white/80">{formatAddress(tx.from)}</span>
                        </p>
                        <p className="text-sm">
                          <span className="text-white/60">Amount:</span>{' '}
                          <span className="font-semibold text-white">{formatTransactionValue(tx.value)}</span>
                        </p>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <p className="text-sm text-white/50">
                        {tx.timestamp ? new Date(tx.timestamp * 1000).toLocaleDateString() : 'Unknown'}
                      </p>
                      {tx.blockNumber && (
                        <p className="text-xs text-white/40 mt-1">
                          Block #{tx.blockNumber}
                        </p>
                      )}
                    </div>
                  </div>
                  
                  {tx.hash && (
                    <div className="mt-4 pt-4 border-t border-white/10">
                      <p className="text-xs text-white/50">
                        Hash: <span className="font-mono text-white/70">{formatAddress(tx.hash)}</span>
                      </p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
} 