"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet, formatAddress } from "@/lib/wallet";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

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
    refreshTransactions,
    miningStats,
    isMining
  } = useWallet();
  const [recoveryPhrase, setRecoveryPhrase] = useState("");
  const [numiBalance, setNumiBalance] = useState("0");
  const [stakedAmount, setStakedAmount] = useState("0");
  const [votingPower, setVotingPower] = useState("0");
  const router = useRouter();

  useEffect(() => {
    // Check if wallet exists, if not redirect to onboarding
    if (!hasWallet()) {
      router.push("/onboarding");
    }
  }, [router]);

  const handleUnlock = async (e: React.FormEvent) => {
    e.preventDefault();
    await unlock(recoveryPhrase);
  };

  const handleLogout = () => {
    lock();
    setRecoveryPhrase("");
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
          <Card className="text-center">
            <CardHeader>
              <CardTitle className="text-3xl mb-2">Welcome Back</CardTitle>
              <CardDescription>Unlock your wallet to continue</CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleUnlock} className="space-y-6">
                <div>
                  <label htmlFor="recoveryPhrase" className="block text-sm font-medium text-white/90 mb-2">
                    Recovery Phrase
                  </label>
                  <textarea
                    id="recoveryPhrase"
                    value={recoveryPhrase}
                    onChange={(e) => setRecoveryPhrase(e.target.value)}
                    className="w-full h-24 resize-none rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                    placeholder="Enter your 12-word recovery phrase"
                    disabled={loading}
                  />
                  <p className="text-xs text-white/60 mt-2">
                    Enter all 12 words in order, separated by spaces
                  </p>
                </div>

                {error && (
                  <div className="p-3 rounded-md bg-red-500/20 border border-red-500/30 text-red-200">
                    {error}
                  </div>
                )}

                <Button
                  type="submit"
                  disabled={loading || recoveryPhrase.trim().split(' ').length !== 12}
                  className="w-full"
                >
                  {loading ? "Unlocking..." : "Unlock Wallet"}
                </Button>
              </form>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header Card */}
        <Card>
          <CardHeader>
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <div>
                <CardTitle className="text-2xl md:text-3xl">Dashboard</CardTitle>
                <CardDescription>Manage your NumiCoin ecosystem</CardDescription>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  onClick={refreshBalance}
                  disabled={balanceLoading}
                  size="sm"
                >
                  {balanceLoading ? "Refreshing..." : "Refresh"}
                </Button>
                <Button
                  variant="destructive"
                  onClick={handleLogout}
                  size="sm"
                >
                  Lock Wallet
                </Button>
              </div>
            </div>
          </CardHeader>
        </Card>

        {/* Balance & Address Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Wallet Address</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center justify-between">
                <p className="text-sm font-mono text-white/80 break-all">
                  {wallet?.address}
                </p>
                <Button
                  variant="outline"
                  onClick={copyAddress}
                  size="sm"
                  className="ml-2 flex-shrink-0"
                >
                  Copy
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Balances</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-white/70">ETH Balance:</span>
                  <p className="text-xl font-bold gradient-text">
                    {balanceLoading ? (
                      <span className="loading-shimmer">Loading...</span>
                    ) : (
                      `${parseFloat(balance).toFixed(6)} ETH`
                    )}
                  </p>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-white/70">NUMI Balance:</span>
                  <p className="text-xl font-bold gradient-text">
                    {parseFloat(numiBalance).toFixed(2)} NUMI
                  </p>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-white/70">Staked NUMI:</span>
                  <p className="text-lg font-semibold text-green-400">
                    {parseFloat(stakedAmount).toFixed(2)} NUMI
                  </p>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-white/70">Voting Power:</span>
                  <p className="text-lg font-semibold text-blue-400">
                    {parseFloat(votingPower).toFixed(2)} NUMI
                  </p>
                </div>
              </div>
              {isMining() && (
                <div className="mt-4 flex items-center gap-2">
                  <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                  <span className="text-sm text-green-400">Mining Active</span>
                  <Badge variant="secondary">
                    {miningStats.currentBlock} blocks mined
                  </Badge>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Quick Actions */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              <Button 
                onClick={() => router.push("/send")}
                className="h-16"
              >
                Send
              </Button>
              <Button 
                onClick={() => router.push("/receive")}
                className="h-16"
              >
                Receive
              </Button>
              <Button 
                onClick={() => router.push("/miner")}
                variant="outline"
                className="h-16"
              >
                Mine
              </Button>
              <Button 
                onClick={() => router.push("/stake")}
                variant="success"
                className="h-16"
              >
                Stake
              </Button>
              <Button 
                onClick={() => router.push("/governance")}
                variant="outline"
                className="h-16"
              >
                Vote
              </Button>
              <Button 
                onClick={() => router.push("/analytics")}
                variant="outline"
                className="h-16"
              >
                Analytics
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Governance Overview */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Governance Overview</CardTitle>
            <CardDescription>Your participation in NumiCoin ecosystem decisions</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="text-center">
                <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                  <span className="text-xl">🗳️</span>
                </div>
                <h4 className="font-semibold mb-2">Voting Power</h4>
                <p className="text-2xl font-bold gradient-text">
                  {parseFloat(votingPower).toFixed(2)} NUMI
                </p>
                <p className="text-xs text-white/50 mt-1">Based on staked tokens</p>
              </div>
              
              <div className="text-center">
                <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                  <span className="text-xl">📋</span>
                </div>
                <h4 className="font-semibold mb-2">Proposal Threshold</h4>
                <p className="text-2xl font-bold gradient-text">
                  1,000 NUMI
                </p>
                <p className="text-xs text-white/50 mt-1">Required to create proposals</p>
              </div>
              
              <div className="text-center">
                <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                  <span className="text-xl">⚡</span>
                </div>
                <h4 className="font-semibold mb-2">Mining-Only</h4>
                <p className="text-sm text-white/70">
                  NUMI tokens can only be earned through mining
                </p>
                <p className="text-xs text-white/50 mt-1">No airdrops or presales</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Transaction History */}
        <Card>
          <CardHeader>
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <CardTitle className="text-xl">Transaction History</CardTitle>
              <Button
                variant="outline"
                onClick={refreshTransactions}
                disabled={transactionsLoading}
                size="sm"
              >
                {transactionsLoading ? "Refreshing..." : "Refresh"}
              </Button>
            </div>
          </CardHeader>
          <CardContent>
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
              <Tabs defaultValue="all" className="w-full">
                <TabsList className="grid w-full grid-cols-3">
                  <TabsTrigger value="all">All</TabsTrigger>
                  <TabsTrigger value="sent">Sent</TabsTrigger>
                  <TabsTrigger value="received">Received</TabsTrigger>
                </TabsList>
                <TabsContent value="all" className="space-y-4 max-h-96 overflow-y-auto">
                  {transactions.map((tx, index) => (
                    <Card key={tx.hash || index} className="bg-white/5 hover:bg-white/10 transition-all duration-200">
                      <CardContent className="p-4">
                        <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-3">
                              <Badge variant={tx.type === 'sent' ? 'destructive' : 'success'}>
                                {tx.type === 'sent' ? 'Sent' : 'Received'}
                              </Badge>
                              <Badge variant="outline">
                                {getTransactionStatus(tx)}
                              </Badge>
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
                      </CardContent>
                    </Card>
                  ))}
                </TabsContent>
                <TabsContent value="sent" className="space-y-4 max-h-96 overflow-y-auto">
                  {transactions.filter(tx => tx.type === 'sent').map((tx, index) => (
                    <Card key={tx.hash || index} className="bg-white/5 hover:bg-white/10 transition-all duration-200">
                      <CardContent className="p-4">
                        {/* Same content as above but filtered for sent transactions */}
                      </CardContent>
                    </Card>
                  ))}
                </TabsContent>
                <TabsContent value="received" className="space-y-4 max-h-96 overflow-y-auto">
                  {transactions.filter(tx => tx.type === 'received').map((tx, index) => (
                    <Card key={tx.hash || index} className="bg-white/5 hover:bg-white/10 transition-all duration-200">
                      <CardContent className="p-4">
                        {/* Same content as above but filtered for received transactions */}
                      </CardContent>
                    </Card>
                  ))}
                </TabsContent>
              </Tabs>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 