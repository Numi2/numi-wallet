"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet } from "@/lib/wallet";
import { ethers } from "ethers";

export default function StakePage() {
  const { 
    wallet, 
    isLocked,
    miningStats,
    startMining,
    stopMining,
    isMining,
    refreshMiningStats
  } = useWallet();
  const [stakeAmount, setStakeAmount] = useState("");
  const [unstakeAmount, setUnstakeAmount] = useState("");
  const [stakingStats, setStakingStats] = useState({
    stakedAmount: "0",
    pendingRewards: "0",
    lastStakeTime: 0,
    totalStaked: "0",
    stakingRewardRate: "5"
  });
  const [loading, setLoading] = useState(false);
  const [showStakeModal, setShowStakeModal] = useState(false);
  const [showUnstakeModal, setShowUnstakeModal] = useState(false);
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

    // Load staking stats
    loadStakingStats();
  }, [router, isLocked]);

  const loadStakingStats = async () => {
    if (!wallet) return;
    
    try {
      // This would be replaced with actual contract calls
      // For now, using mock data
      setStakingStats({
        stakedAmount: "0",
        pendingRewards: "0",
        lastStakeTime: 0,
        totalStaked: "1000000",
        stakingRewardRate: "5"
      });
    } catch (error) {
      console.error("Failed to load staking stats:", error);
    }
  };

  const handleStake = async () => {
    if (!wallet || !stakeAmount || parseFloat(stakeAmount) <= 0) return;
    
    setLoading(true);
    try {
      // This would be replaced with actual contract call
      console.log("Staking", stakeAmount, "NUMI");
      
      // Simulate transaction
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      setShowStakeModal(false);
      setStakeAmount("");
      await loadStakingStats();
    } catch (error) {
      console.error("Failed to stake:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleUnstake = async () => {
    if (!wallet || !unstakeAmount || parseFloat(unstakeAmount) <= 0) return;
    
    setLoading(true);
    try {
      // This would be replaced with actual contract call
      console.log("Unstaking", unstakeAmount, "NUMI");
      
      // Simulate transaction
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      setShowUnstakeModal(false);
      setUnstakeAmount("");
      await loadStakingStats();
    } catch (error) {
      console.error("Failed to unstake:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleClaimRewards = async () => {
    if (!wallet) return;
    
    setLoading(true);
    try {
      // This would be replaced with actual contract call
      console.log("Claiming staking rewards");
      
      // Simulate transaction
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      await loadStakingStats();
    } catch (error) {
      console.error("Failed to claim rewards:", error);
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (timestamp: number): string => {
    if (!timestamp) return "Never";
    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString() + " " + date.toLocaleTimeString();
  };

  const calculateAPY = (): string => {
    return stakingStats.stakingRewardRate;
  };

  const calculateDailyRewards = (): string => {
    const staked = parseFloat(stakingStats.stakedAmount);
    const apy = parseFloat(stakingStats.stakingRewardRate);
    const dailyRate = apy / 365;
    return (staked * dailyRate / 100).toFixed(2);
  };

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div className="glass-card">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold gradient-text">Stake NUMI</h1>
              <p className="text-white/70 mt-1">Earn rewards and gain governance power by staking your NUMI tokens</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => router.push("/dashboard")}
                className="glass-button-secondary touch-target text-sm"
              >
                Back to Dashboard
              </button>
              <button
                onClick={() => router.push("/miner")}
                className="glass-button-secondary touch-target text-sm"
              >
                Go Mining
              </button>
            </div>
          </div>
        </div>

        {/* Staking Benefits */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="glass-card bg-green-500/20 border border-green-500/30">
            <div className="text-center">
              <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                <span className="text-xl">💰</span>
              </div>
              <h4 className="font-semibold text-green-200 mb-2">Earn Rewards</h4>
              <p className="text-green-100 text-sm">Earn 5% APY on your staked NUMI tokens</p>
            </div>
          </div>
          
          <div className="glass-card bg-blue-500/20 border border-blue-500/30">
            <div className="text-center">
              <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                <span className="text-xl">🗳️</span>
              </div>
              <h4 className="font-semibold text-blue-200 mb-2">Governance Power</h4>
              <p className="text-blue-100 text-sm">Staked tokens give you voting power in governance</p>
            </div>
          </div>
          
          <div className="glass-card bg-purple-500/20 border border-purple-500/30">
            <div className="text-center">
              <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                <span className="text-xl">⚡</span>
              </div>
              <h4 className="font-semibold text-purple-200 mb-2">Mining-Only</h4>
              <p className="text-purple-100 text-sm">NUMI can only be earned through mining - no handouts</p>
            </div>
          </div>
        </div>

        {/* Staking Overview */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Your Staked</h4>
            <p className="text-2xl font-bold gradient-text">
              {parseFloat(stakingStats.stakedAmount).toFixed(2)} NUMI
            </p>
            <p className="text-xs text-white/50 mt-1">Your voting power</p>
          </div>
          
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Pending Rewards</h4>
            <p className="text-2xl font-bold gradient-text">
              {parseFloat(stakingStats.pendingRewards).toFixed(4)} NUMI
            </p>
          </div>
          
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">APY Rate</h4>
            <p className="text-2xl font-bold gradient-text">
              {calculateAPY()}%
            </p>
          </div>
          
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Daily Rewards</h4>
            <p className="text-2xl font-bold gradient-text">
              {calculateDailyRewards()} NUMI
            </p>
          </div>
        </div>

        {/* Staking Actions */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Stake */}
          <div className="glass-card">
            <h3 className="text-lg font-semibold text-white/90 mb-4">Stake NUMI</h3>
            <p className="text-white/70 text-sm mb-4">
              Stake your NUMI tokens to earn rewards and gain governance voting power. 
              Only staked tokens count for governance participation.
            </p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-white/70 mb-2">
                  Amount to Stake
                </label>
                <input
                  type="number"
                  value={stakeAmount}
                  onChange={(e) => setStakeAmount(e.target.value)}
                  placeholder="0.0"
                  className="glass-input w-full"
                  disabled={loading}
                />
              </div>
              
              <button
                onClick={() => setShowStakeModal(true)}
                disabled={loading || !stakeAmount || parseFloat(stakeAmount) <= 0}
                className="glass-button w-full touch-target disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Stake NUMI
              </button>
            </div>
          </div>

          {/* Unstake */}
          <div className="glass-card">
            <h3 className="text-lg font-semibold text-white/90 mb-4">Unstake NUMI</h3>
            <p className="text-white/70 text-sm mb-4">
              Unstake your tokens to withdraw them. This will reduce your voting power 
              and stop earning staking rewards on the unstaked amount.
            </p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-white/70 mb-2">
                  Amount to Unstake
                </label>
                <input
                  type="number"
                  value={unstakeAmount}
                  onChange={(e) => setUnstakeAmount(e.target.value)}
                  placeholder="0.0"
                  className="glass-input w-full"
                  disabled={loading}
                />
              </div>
              
              <button
                onClick={() => setShowUnstakeModal(true)}
                disabled={loading || !unstakeAmount || parseFloat(unstakeAmount) <= 0}
                className="glass-button-secondary w-full touch-target disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Unstake NUMI
              </button>
            </div>
          </div>
        </div>

        {/* Claim Rewards */}
        <div className="glass-card">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <h3 className="text-lg font-semibold text-white/90 mb-2">Staking Rewards</h3>
              <p className="text-white/70 text-sm">
                Claim your accumulated staking rewards. Rewards are automatically calculated 
                based on your staked amount and time staked.
              </p>
            </div>
            
            <button
              onClick={handleClaimRewards}
              disabled={loading || parseFloat(stakingStats.pendingRewards) <= 0}
              className="glass-button-success touch-target disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "Claiming..." : "Claim Rewards"}
            </button>
          </div>
        </div>

        {/* Staking Info */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-4">Staking Information</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h4 className="font-medium text-white/80 mb-3">Staking Details</h4>
              <div className="space-y-2 text-sm text-white/70">
                <div className="flex justify-between">
                  <span>Last Staked:</span>
                  <span>{formatTime(stakingStats.lastStakeTime)}</span>
                </div>
                <div className="flex justify-between">
                  <span>Total Staked (Network):</span>
                  <span>{parseFloat(stakingStats.totalStaked).toLocaleString()} NUMI</span>
                </div>
                <div className="flex justify-between">
                  <span>APY Rate:</span>
                  <span>{calculateAPY()}%</span>
                </div>
              </div>
            </div>
            
            <div>
              <h4 className="font-medium text-white/80 mb-3">Governance Benefits</h4>
              <div className="space-y-2 text-sm text-white/70">
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 bg-green-400 rounded-full"></span>
                  <span>Voting power equals staked amount</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 bg-green-400 rounded-full"></span>
                  <span>Create proposals with 1000+ staked NUMI</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 bg-green-400 rounded-full"></span>
                  <span>Participate in ecosystem decisions</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Mining Notice */}
        <div className="glass-card bg-orange-500/20 border border-orange-500/30">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 glass-card flex items-center justify-center">
              <span className="text-orange-300">⛏️</span>
            </div>
            <div>
              <h4 className="font-semibold text-orange-200">Mining-Only Token Distribution</h4>
              <p className="text-orange-100 text-sm">
                NUMI tokens can only be earned through mining. There are no airdrops, presales, 
                or initial distributions. Start mining to earn your first NUMI tokens!
                <button 
                  onClick={() => router.push("/miner")}
                  className="underline ml-1 hover:text-orange-300"
                >
                  Start mining now
                </button>
              </p>
            </div>
          </div>
        </div>

        {/* Stake Modal */}
        {showStakeModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
            <div className="glass-card max-w-md w-full">
              <h3 className="text-lg font-semibold text-white/90 mb-4">Confirm Stake</h3>
              
              <div className="space-y-4">
                <div className="text-center">
                  <p className="text-white/70 mb-2">You are about to stake:</p>
                  <p className="text-2xl font-bold gradient-text">{stakeAmount} NUMI</p>
                </div>
                
                <div className="bg-blue-500/20 border border-blue-500/30 rounded-lg p-3">
                  <p className="text-blue-200 text-sm">
                    <strong>Benefits:</strong>
                  </p>
                  <ul className="text-blue-100 text-sm mt-1 space-y-1">
                    <li>• Earn 5% APY on staked amount</li>
                    <li>• Gain {stakeAmount} voting power</li>
                    <li>• Participate in governance</li>
                  </ul>
                </div>
                
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowStakeModal(false)}
                    disabled={loading}
                    className="glass-button-secondary flex-1 touch-target"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleStake}
                    disabled={loading}
                    className="glass-button flex-1 touch-target"
                  >
                    {loading ? "Staking..." : "Confirm Stake"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Unstake Modal */}
        {showUnstakeModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
            <div className="glass-card max-w-md w-full">
              <h3 className="text-lg font-semibold text-white/90 mb-4">Confirm Unstake</h3>
              
              <div className="space-y-4">
                <div className="text-center">
                  <p className="text-white/70 mb-2">You are about to unstake:</p>
                  <p className="text-2xl font-bold gradient-text">{unstakeAmount} NUMI</p>
                </div>
                
                <div className="bg-yellow-500/20 border border-yellow-500/30 rounded-lg p-3">
                  <p className="text-yellow-200 text-sm">
                    <strong>Effects:</strong>
                  </p>
                  <ul className="text-yellow-100 text-sm mt-1 space-y-1">
                    <li>• Stop earning rewards on this amount</li>
                    <li>• Reduce voting power by {unstakeAmount}</li>
                    <li>• Tokens will be returned to your wallet</li>
                  </ul>
                </div>
                
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowUnstakeModal(false)}
                    disabled={loading}
                    className="glass-button-secondary flex-1 touch-target"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleUnstake}
                    disabled={loading}
                    className="glass-button flex-1 touch-target"
                  >
                    {loading ? "Unstaking..." : "Confirm Unstake"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
} 