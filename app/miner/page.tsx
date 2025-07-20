"use client";

import { useState, useEffect } from "react";
import { useWallet } from "@/context/WalletContext";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function MinerPage() {
  const {
    isLocked,
    address,
    balance,
    isMining,
    miningStats,
    blockchainStats,
    startMining,
    stopMining,
    refreshMiningStats,
  } = useWallet();

  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Auto-refresh stats every 2 seconds when mining
  useEffect(() => {
    if (isMining) {
      const interval = setInterval(() => {
        refreshMiningStats();
      }, 2000);
      return () => clearInterval(interval);
    }
  }, [isMining, refreshMiningStats]);

  const handleStartMining = async () => {
    setError(null);
    setLoading(true);
    try {
      await startMining();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start mining");
    } finally {
      setLoading(false);
    }
  };

  const handleStopMining = async () => {
    setError(null);
    setLoading(true);
    try {
      await stopMining();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to stop mining");
    } finally {
      setLoading(false);
    }
  };

  if (isLocked) {
    return (
      <div className="min-h-screen p-4 md:p-8" style={{ 
        background: 'linear-gradient(135deg, rgba(15, 15, 35, 0.8) 0%, rgba(26, 26, 46, 0.9) 100%), url("/dong-zhang-ILYVeUgPkmI-unsplash.jpg") no-repeat center center fixed',
        backgroundSize: 'cover',
        backgroundAttachment: 'fixed'
      }}>
        <div className="max-w-4xl mx-auto">
          <Card className="bg-white/10 backdrop-blur-xl border-white/20">
            <CardContent className="p-8 text-center">
              <div className="text-4xl mb-4">🔒</div>
              <h2 className="text-2xl font-bold text-white mb-4">Wallet Locked</h2>
              <p className="text-blue-200 mb-6">
                Please unlock your wallet to start mining NumiCoin.
              </p>
              <Button 
                onClick={() => window.history.back()}
                className="bg-blue-600 hover:bg-blue-700 text-white"
              >
                Go Back
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 md:p-8" style={{ 
      background: 'linear-gradient(135deg, rgba(15, 15, 35, 0.8) 0%, rgba(26, 26, 46, 0.9) 100%), url("/dong-zhang-ILYVeUgPkmI-unsplash.jpg") no-repeat center center fixed',
      backgroundSize: 'cover',
      backgroundAttachment: 'fixed'
    }}>
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-4xl md:text-6xl font-bold text-white mb-4">
            ⛏️ NumiCoin Mining
          </h1>
          <p className="text-xl text-blue-200">
            Mine The People's Coin - Completely FREE!
          </p>
          <Badge variant="secondary" className="text-lg px-4 py-2 bg-green-500/20 text-green-300 border-green-500/30">
            💎 Zero Gas Costs • Blake3 Algorithm • Quantum Safe
          </Badge>
        </div>

        {/* Free Mining Notice */}
        <Alert className="bg-green-500/20 border-green-500/30">
          <AlertDescription className="text-green-200">
            <strong>🎉 FREE MINING!</strong> NumiCoin uses a custom blockchain with zero gas costs. 
            Mine as much as you want without paying any fees. This is true "People's Coin" mining!
          </AlertDescription>
        </Alert>

        {/* Mining Controls */}
        <Card className="bg-white/10 backdrop-blur-xl border-white/20">
          <CardHeader>
            <CardTitle className="text-white text-2xl">Mining Controls</CardTitle>
            <CardDescription className="text-blue-200">
              Start or stop mining NumiCoin with your device's computational power
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex flex-col sm:flex-row gap-4">
              <Button
                onClick={handleStartMining}
                disabled={isMining || loading}
                className="flex-1 h-16 text-lg font-semibold bg-green-600 hover:bg-green-700 text-white border-0"
              >
                {loading ? (
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 border-2 border-white/20 border-t-white rounded-full animate-spin"></div>
                    Starting...
                  </div>
                ) : (
                  <>
                    <span className="text-2xl mr-2">🚀</span>
                    Start Mining
                  </>
                )}
              </Button>
              
              <Button
                onClick={handleStopMining}
                disabled={!isMining || loading}
                variant="outline"
                className="flex-1 h-16 text-lg font-semibold border-red-500/30 text-red-300 hover:bg-red-500/10"
              >
                <span className="text-2xl mr-2">⏹️</span>
                Stop Mining
              </Button>
            </div>

            {error && (
              <Alert className="bg-red-500/20 border-red-500/30">
                <AlertDescription className="text-red-200">
                  {error}
                </AlertDescription>
              </Alert>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
              <div className="text-center p-4 rounded-lg bg-blue-500/20 border-blue-500/30">
                <div className="text-2xl font-bold text-white">{balance.toFixed(3)}</div>
                <div className="text-blue-200">NUMI Balance</div>
              </div>
              
              <div className="text-center p-4 rounded-lg bg-purple-500/20 border-purple-500/30">
                <div className="text-2xl font-bold text-white">{miningStats.blocksMined}</div>
                <div className="text-purple-200">Blocks Mined</div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Mining Statistics */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Personal Mining Stats */}
          <Card className="bg-white/10 backdrop-blur-xl border-white/20">
            <CardHeader>
              <CardTitle className="text-white text-xl">Your Mining Stats</CardTitle>
              <CardDescription className="text-blue-200">
                Real-time statistics from your mining session
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="text-center p-3 rounded-lg bg-blue-500/20">
                  <div className="text-lg font-bold text-white">
                    {miningStats.hashRate.toLocaleString()}
                  </div>
                  <div className="text-sm text-blue-200">Hash Rate</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-green-500/20">
                  <div className="text-lg font-bold text-white">
                    {miningStats.totalHashes.toLocaleString()}
                  </div>
                  <div className="text-sm text-green-200">Total Hashes</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-purple-500/20">
                  <div className="text-lg font-bold text-white">
                    {miningStats.currentBlock}
                  </div>
                  <div className="text-sm text-purple-200">Current Block</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-yellow-500/20">
                  <div className="text-lg font-bold text-white">
                    {miningStats.difficulty}
                  </div>
                  <div className="text-sm text-yellow-200">Difficulty</div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Blockchain Stats */}
          <Card className="bg-white/10 backdrop-blur-xl border-white/20">
            <CardHeader>
              <CardTitle className="text-white text-xl">NumiCoin Blockchain</CardTitle>
              <CardDescription className="text-blue-200">
                Global blockchain statistics
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="text-center p-3 rounded-lg bg-blue-500/20">
                  <div className="text-lg font-bold text-white">
                    {blockchainStats.totalBlocks}
                  </div>
                  <div className="text-sm text-blue-200">Total Blocks</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-green-500/20">
                  <div className="text-lg font-bold text-white">
                    {blockchainStats.totalSupply.toFixed(3)}
                  </div>
                  <div className="text-sm text-green-200">Total Supply</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-purple-500/20">
                  <div className="text-lg font-bold text-white">
                    {blockchainStats.activeMiners}
                  </div>
                  <div className="text-sm text-purple-200">Active Miners</div>
                </div>
                
                <div className="text-center p-3 rounded-lg bg-yellow-500/20">
                  <div className="text-lg font-bold text-white">
                    {blockchainStats.averageBlockTime.toFixed(1)}s
                  </div>
                  <div className="text-sm text-yellow-200">Avg Block Time</div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Mining Information */}
        <Card className="bg-gradient-to-r from-blue-500/20 to-purple-500/20 border-blue-500/30">
          <CardContent className="p-6">
            <h3 className="text-xl font-semibold text-white mb-4">How NumiCoin Mining Works</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-blue-100">
              <div>
                                 <h4 className="font-semibold text-white mb-2">🔬 Blake3 Algorithm (Quantum-Safe)</h4>
                <ul className="space-y-1 text-sm">
                  <li>• Quantum-safe cryptographic hash function</li>
                  <li>• Faster and more secure than SHA-256</li>
                  <li>• Optimized for modern hardware</li>
                  <li>• Resistant to future quantum attacks</li>
                </ul>
              </div>
              
              <div>
                <h4 className="font-semibold text-white mb-2">💎 Free Mining</h4>
                <ul className="space-y-1 text-sm">
                  <li>• Zero gas costs - mine for free!</li>
                  <li>• 0.005 NUMI reward per block</li>
                  <li>• Custom blockchain implementation</li>
                  <li>• True "People's Coin" philosophy</li>
                </ul>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Wallet Info */}
        <Card className="bg-white/10 backdrop-blur-xl border-white/20">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold text-white">Mining Address</h3>
                <p className="text-blue-200 text-sm font-mono">{address}</p>
              </div>
              <Badge variant="secondary" className="bg-green-500/20 text-green-300 border-green-500/30">
                Connected
              </Badge>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 