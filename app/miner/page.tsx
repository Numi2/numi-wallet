"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet } from "@/lib/wallet";
import { MiningConfig } from "@/lib/miner";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function MinerPage() {
  const { 
    wallet, 
    isLocked,
    miningStats,
    startMining,
    stopMining,
    isMining
  } = useWallet();
  const [config, setConfig] = useState<MiningConfig>({
    difficulty: 2, // Updated to match new easier difficulty
    blockReward: 0.005, // Updated to match new higher rewards
    maxWorkers: 4,
    updateInterval: 500, // Updated to match new faster updates
  });
  const [showConfig, setShowConfig] = useState(false);
  const router = useRouter();

  useEffect(() => {
    // Check if wallet exists, if not redirect to onboarding
    if (!hasWallet()) {
      router.push("/onboarding");
      return;
    }

    // Check if wallet is locked, if so redirect to dashboard
    if (isLocked) {
      router.push("/dashboard");
      return;
    }

    // Load current mining config with easier settings
    setConfig({
      difficulty: 2, // Much easier to mine!
      blockReward: 0.005, // More generous rewards!
      maxWorkers: 4,
      updateInterval: 500, // More responsive updates
    });
  }, [router, isLocked]);

  const handleStartMining = async () => {
    try {
      await startMining();
    } catch (error) {
      console.error("Failed to start mining:", error);
    }
  };

  const handleStopMining = () => {
    stopMining();
  };

  const handleConfigChange = (key: keyof MiningConfig, value: number) => {
    const newConfig = { ...config, [key]: value };
    setConfig(newConfig);
    // Note: Config updates are now handled by the smart contract
  };

  const formatHashRate = (hashesPerSecond: number): string => {
    if (hashesPerSecond >= 1000000) {
      return `${(hashesPerSecond / 1000000).toFixed(2)} MH/s`;
    } else if (hashesPerSecond >= 1000) {
      return `${(hashesPerSecond / 1000).toFixed(2)} KH/s`;
    } else {
      return `${hashesPerSecond} H/s`;
    }
  };

  const formatTime = (timestamp?: number): string => {
    if (!timestamp) return "Never";
    const date = new Date(timestamp);
    return date.toLocaleTimeString();
  };

  const getEstimatedReward = (): string => {
    const hps = miningStats.hashesPerSecond;
    const difficulty = miningStats.difficulty;
    const blockReward = config.blockReward;
    
    // Simple estimation: higher difficulty = more time needed
    // This is a very rough estimate
    const estimatedTimePerBlock = Math.pow(16, difficulty) / hps;
    const blocksPerHour = 3600 / estimatedTimePerBlock;
    const rewardPerHour = blocksPerHour * blockReward;
    
    return rewardPerHour.toFixed(6);
  };

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <Card>
          <CardHeader>
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <div>
                <CardTitle className="text-2xl md:text-3xl">NumiMiner</CardTitle>
                <CardDescription className="text-lg mt-2">
                  Mine NumiCoin with your device's computational power - Now easier than ever! ��
                </CardDescription>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button
                  onClick={() => router.push("/dashboard")}
                  variant="outline"
                  size="sm"
                >
                  Back to Dashboard
                </Button>
                <Button
                  onClick={() => setShowConfig(!showConfig)}
                  variant="outline"
                  size="sm"
                >
                  {showConfig ? "Hide Config" : "Show Config"}
                </Button>
              </div>
            </div>
          </CardHeader>
        </Card>

        {/* People's Coin Banner */}
        <Card className="bg-gradient-to-r from-green-500/20 to-blue-500/20 border-green-500/30">
          <CardContent className="p-6">
            <div className="flex items-center gap-3">
              <div className="text-2xl">🌟</div>
              <div>
                <h3 className="text-lg font-semibold text-green-200">NumiCoin - The People's Coin</h3>
                <p className="text-green-100/80">
                  Designed to be easy to mine and accessible to everyone. No initial distributions - 
                  earn your coins through honest work!
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Mining Controls */}
        <Card>
          <CardHeader>
            <CardTitle>Mining Controls</CardTitle>
            <CardDescription>
              Start mining to earn NumiCoin rewards. The difficulty has been reduced to make mining accessible to everyone!
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col md:flex-row gap-4">
              <Button
                onClick={handleStartMining}
                disabled={isMining()}
                size="lg"
                className="flex-1 h-16 text-lg font-semibold"
              >
                {isMining() ? (
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 border-2 border-white/20 border-t-white rounded-full animate-spin"></div>
                    Mining...
                  </div>
                ) : (
                  "🚀 Start Mining"
                )}
              </Button>
              <Button
                onClick={handleStopMining}
                disabled={!isMining()}
                variant="destructive"
                size="lg"
                className="flex-1 h-16 text-lg font-semibold"
              >
                Stop Mining
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Mining Statistics */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <Card>
            <CardContent className="p-6">
              <h4 className="text-sm font-medium text-white/70 mb-2">Hash Rate</h4>
              <p className="text-2xl font-bold gradient-text">
                {formatHashRate(miningStats.hashesPerSecond)}
              </p>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Hashes</h4>
              <p className="text-2xl font-bold gradient-text">
                {miningStats.totalHashes.toLocaleString()}
              </p>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <h4 className="text-sm font-medium text-white/70 mb-2">Block Reward</h4>
              <p className="text-2xl font-bold gradient-text">
                {config.blockReward} NUMI
              </p>
              <Badge variant="success" className="mt-2">Increased Rewards!</Badge>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <h4 className="text-sm font-medium text-white/70 mb-2">Current Block</h4>
              <p className="text-2xl font-bold gradient-text">
                #{miningStats.currentBlock}
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Mining Status */}
        <Card>
          <CardHeader>
            <CardTitle>Mining Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Status</h4>
                <div className="flex items-center gap-2">
                  <div className={`w-3 h-3 rounded-full ${isMining() ? 'bg-green-500' : 'bg-red-500'}`}></div>
                  <span className="text-white/90">
                    {isMining() ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>
              
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Difficulty</h4>
                <div className="flex items-center gap-2">
                  <p className="text-white/90">{miningStats.difficulty} leading zeros</p>
                  <Badge variant="success">Easy Mining!</Badge>
                </div>
              </div>
              
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Current Block</h4>
                <p className="text-white/90">#{miningStats.currentBlock}</p>
              </div>
              
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Last Mine Time</h4>
                <p className="text-white/90">{formatTime(miningStats.lastMineTime)}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Estimated Rewards */}
        <Card>
          <CardHeader>
            <CardTitle>Estimated Rewards</CardTitle>
            <CardDescription>
              Based on current hash rate and difficulty
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Per Hour</h4>
                <p className="text-xl font-bold gradient-text">
                  {getEstimatedReward()} NUMI
                </p>
              </div>
              
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Per Day</h4>
                <p className="text-xl font-bold gradient-text">
                  {(parseFloat(getEstimatedReward()) * 24).toFixed(6)} NUMI
                </p>
              </div>
              
              <div>
                <h4 className="text-sm font-medium text-white/70 mb-2">Per Week</h4>
                <p className="text-xl font-bold gradient-text">
                  {(parseFloat(getEstimatedReward()) * 24 * 7).toFixed(6)} NUMI
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Configuration Panel */}
        {showConfig && (
          <Card>
            <CardHeader>
              <CardTitle>Mining Configuration</CardTitle>
              <CardDescription>
                Current settings for NumiCoin mining
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-white/90 mb-2">
                    Difficulty: {config.difficulty}
                  </label>
                  <p className="text-xs text-white/60 mb-4">
                    Reduced from 4 to 2 - much easier to mine!
                  </p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-white/90 mb-2">
                    Block Reward: {config.blockReward} NUMI
                  </label>
                  <p className="text-xs text-white/60 mb-4">
                    Increased from 0.001 to 0.005 - more generous!
                  </p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-white/90 mb-2">
                    Max Workers: {config.maxWorkers}
                  </label>
                  <p className="text-xs text-white/60 mb-4">
                    Uses your device's CPU cores efficiently
                  </p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-white/90 mb-2">
                    Update Interval: {config.updateInterval}ms
                  </label>
                  <p className="text-xs text-white/60 mb-4">
                    Faster updates for better user experience
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Mining Tips */}
        <Card className="bg-blue-500/10 border-blue-500/30">
          <CardContent className="p-6">
            <h3 className="text-lg font-semibold text-blue-200 mb-4">💡 Mining Tips</h3>
            <ul className="space-y-2 text-blue-100/80">
              <li>• NumiCoin is designed to be easy to mine - perfect for beginners!</li>
              <li>• Keep your browser tab open while mining for best results</li>
              <li>• The difficulty adjusts automatically to keep mining accessible</li>
              <li>• Earn rewards every time you successfully mine a block</li>
              <li>• No special hardware required - your regular device works great!</li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 