"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet } from "@/lib/wallet";

interface AnalyticsData {
  mining: {
    totalBlocksMined: number;
    totalRewards: string;
    averageHashRate: string;
    bestHashRate: string;
    miningEfficiency: number;
    difficultyHistory: number[];
    rewardsHistory: string[];
  };
  staking: {
    totalStaked: string;
    totalRewards: string;
    averageAPY: number;
    stakingEfficiency: number;
    stakingHistory: string[];
    rewardsHistory: string[];
  };
  ecosystem: {
    totalSupply: string;
    circulatingSupply: string;
    totalStaked: string;
    activeMiners: number;
    activeStakers: number;
    governanceParticipation: number;
  };
  performance: {
    dailyMining: string;
    weeklyMining: string;
    monthlyMining: string;
    dailyStaking: string;
    weeklyStaking: string;
    monthlyStaking: string;
  };
}

export default function AnalyticsPage() {
  const { 
    wallet, 
    isLocked,
    miningStats
  } = useWallet();
  const [analytics, setAnalytics] = useState<AnalyticsData>({
    mining: {
      totalBlocksMined: 0,
      totalRewards: "0",
      averageHashRate: "0",
      bestHashRate: "0",
      miningEfficiency: 0,
      difficultyHistory: [4, 4, 5, 4, 5, 6, 5, 4, 5, 6],
      rewardsHistory: ["100", "100", "50", "100", "50", "100", "100", "100", "50", "100"]
    },
    staking: {
      totalStaked: "0",
      totalRewards: "0",
      averageAPY: 5.0,
      stakingEfficiency: 0,
      stakingHistory: ["0", "100", "250", "500", "750", "1000", "1250", "1500", "1750", "2000"],
      rewardsHistory: ["0", "0.14", "0.34", "0.68", "1.03", "1.37", "1.71", "2.05", "2.40", "2.74"]
    },
    ecosystem: {
      totalSupply: "10000000",
      circulatingSupply: "8500000",
      totalStaked: "2000000",
      activeMiners: 1250,
      activeStakers: 3400,
      governanceParticipation: 15.5
    },
    performance: {
      dailyMining: "0",
      weeklyMining: "0",
      monthlyMining: "0",
      dailyStaking: "0",
      weeklyStaking: "0",
      monthlyStaking: "0"
    }
  });
  const [timeRange, setTimeRange] = useState("7d");
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

    // Load analytics data
    loadAnalytics();
  }, [router, isLocked, timeRange]);

  const loadAnalytics = async () => {
    if (!wallet) return;
    
    try {
      // This would be replaced with actual contract calls and API data
      // For now, using enhanced mock data
      setAnalytics(prev => ({
        ...prev,
        mining: {
          ...prev.mining,
          totalBlocksMined: 42,
          totalRewards: "4200",
          averageHashRate: "1250",
          bestHashRate: "2100",
          miningEfficiency: 85
        },
        staking: {
          ...prev.staking,
          totalStaked: "2500",
          totalRewards: "125.50",
          stakingEfficiency: 92
        },
        performance: {
          dailyMining: "100",
          weeklyMining: "700",
          monthlyMining: "3000",
          dailyStaking: "3.42",
          weeklyStaking: "23.94",
          monthlyStaking: "102.60"
        }
      }));
    } catch (error) {
      console.error("Failed to load analytics:", error);
    }
  };

  const formatHashRate = (hashRate: string): string => {
    const num = parseFloat(hashRate);
    if (num >= 1000000) return `${(num / 1000000).toFixed(2)} MH/s`;
    if (num >= 1000) return `${(num / 1000).toFixed(2)} KH/s`;
    return `${num} H/s`;
  };

  const formatCurrency = (amount: string): string => {
    return parseFloat(amount).toLocaleString();
  };

  const getEfficiencyColor = (efficiency: number): string => {
    if (efficiency >= 90) return "text-green-400";
    if (efficiency >= 75) return "text-yellow-400";
    return "text-red-400";
  };

  const getEfficiencyBarColor = (efficiency: number): string => {
    if (efficiency >= 90) return "bg-green-500";
    if (efficiency >= 75) return "bg-yellow-500";
    return "bg-red-500";
  };

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="glass-card">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold gradient-text">Analytics</h1>
              <p className="text-white/70 mt-1">Comprehensive insights into your NumiCoin performance</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => router.push("/dashboard")}
                className="glass-button-secondary touch-target text-sm"
              >
                Back to Dashboard
              </button>
              <select
                value={timeRange}
                onChange={(e) => setTimeRange(e.target.value)}
                className="glass-input text-sm"
              >
                <option value="24h">Last 24 Hours</option>
                <option value="7d">Last 7 Days</option>
                <option value="30d">Last 30 Days</option>
                <option value="90d">Last 90 Days</option>
              </select>
            </div>
          </div>
        </div>

        {/* Mining Analytics */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Mining Performance</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Blocks Mined</h4>
              <p className="text-2xl font-bold gradient-text">
                {analytics.mining.totalBlocksMined}
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Rewards</h4>
              <p className="text-2xl font-bold gradient-text">
                {formatCurrency(analytics.mining.totalRewards)} NUMI
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Average Hash Rate</h4>
              <p className="text-2xl font-bold gradient-text">
                {formatHashRate(analytics.mining.averageHashRate)}
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Best Hash Rate</h4>
              <p className="text-2xl font-bold gradient-text">
                {formatHashRate(analytics.mining.bestHashRate)}
              </p>
            </div>
          </div>
          
          {/* Mining Efficiency */}
          <div className="mt-6">
            <div className="flex items-center justify-between mb-2">
              <h4 className="text-sm font-medium text-white/70">Mining Efficiency</h4>
              <span className={`text-sm font-medium ${getEfficiencyColor(analytics.mining.miningEfficiency)}`}>
                {analytics.mining.miningEfficiency}%
              </span>
            </div>
            <div className="w-full bg-white/10 rounded-full h-2">
              <div 
                className={`h-2 rounded-full transition-all duration-300 ${getEfficiencyBarColor(analytics.mining.miningEfficiency)}`}
                style={{ width: `${analytics.mining.miningEfficiency}%` }}
              />
            </div>
          </div>
        </div>

        {/* Staking Analytics */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Staking Performance</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Staked</h4>
              <p className="text-2xl font-bold gradient-text">
                {formatCurrency(analytics.staking.totalStaked)} NUMI
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Rewards</h4>
              <p className="text-2xl font-bold gradient-text">
                {formatCurrency(analytics.staking.totalRewards)} NUMI
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Average APY</h4>
              <p className="text-2xl font-bold gradient-text">
                {analytics.staking.averageAPY}%
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Staking Efficiency</h4>
              <p className="text-2xl font-bold gradient-text">
                {analytics.staking.stakingEfficiency}%
              </p>
            </div>
          </div>
        </div>

        {/* Performance Metrics */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Performance Metrics</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-4">Mining Rewards</h4>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-white/70">Daily</span>
                  <span className="text-white/90">{formatCurrency(analytics.performance.dailyMining)} NUMI</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/70">Weekly</span>
                  <span className="text-white/90">{formatCurrency(analytics.performance.weeklyMining)} NUMI</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/70">Monthly</span>
                  <span className="text-white/90">{formatCurrency(analytics.performance.monthlyMining)} NUMI</span>
                </div>
              </div>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-4">Staking Rewards</h4>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-white/70">Daily</span>
                  <span className="text-white/90">{formatCurrency(analytics.performance.dailyStaking)} NUMI</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/70">Weekly</span>
                  <span className="text-white/90">{formatCurrency(analytics.performance.weeklyStaking)} NUMI</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/70">Monthly</span>
                  <span className="text-white/90">{formatCurrency(analytics.performance.monthlyStaking)} NUMI</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Ecosystem Overview */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Ecosystem Overview</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Supply</h4>
              <p className="text-xl font-bold gradient-text">
                {formatCurrency(analytics.ecosystem.totalSupply)} NUMI
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Circulating Supply</h4>
              <p className="text-xl font-bold gradient-text">
                {formatCurrency(analytics.ecosystem.circulatingSupply)} NUMI
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Total Staked</h4>
              <p className="text-xl font-bold gradient-text">
                {formatCurrency(analytics.ecosystem.totalStaked)} NUMI
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Active Miners</h4>
              <p className="text-xl font-bold gradient-text">
                {analytics.ecosystem.activeMiners.toLocaleString()}
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Active Stakers</h4>
              <p className="text-xl font-bold gradient-text">
                {analytics.ecosystem.activeStakers.toLocaleString()}
              </p>
            </div>
            
            <div>
              <h4 className="text-sm font-medium text-white/70 mb-2">Governance Participation</h4>
              <p className="text-xl font-bold gradient-text">
                {analytics.ecosystem.governanceParticipation}%
              </p>
            </div>
          </div>
        </div>

        {/* Charts Placeholder */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Performance Charts</h3>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="h-64 bg-white/5 rounded-lg flex items-center justify-center">
              <div className="text-center">
                <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                  <span className="text-2xl">📊</span>
                </div>
                <p className="text-white/70">Mining Performance Chart</p>
                <p className="text-white/50 text-sm">Coming soon with real-time data</p>
              </div>
            </div>
            
            <div className="h-64 bg-white/5 rounded-lg flex items-center justify-center">
              <div className="text-center">
                <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                  <span className="text-2xl">📈</span>
                </div>
                <p className="text-white/70">Staking Rewards Chart</p>
                <p className="text-white/50 text-sm">Coming soon with real-time data</p>
              </div>
            </div>
          </div>
        </div>

        {/* Insights */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-4">Performance Insights</h3>
          <div className="space-y-4 text-white/80">
            <div className="bg-green-500/20 border border-green-500/30 rounded-lg p-4">
              <p className="text-green-200 text-sm">
                <strong>🎯 Excellent Performance:</strong> Your mining efficiency of {analytics.mining.miningEfficiency}% 
                is above the network average. Consider increasing your mining power to maximize rewards.
              </p>
            </div>
            
            <div className="bg-blue-500/20 border border-blue-500/30 rounded-lg p-4">
              <p className="text-blue-200 text-sm">
                <strong>💰 Staking Opportunity:</strong> You're earning {analytics.staking.averageAPY}% APY on staking. 
                Consider staking more tokens to increase your passive income.
              </p>
            </div>
            
            <div className="bg-yellow-500/20 border border-yellow-500/30 rounded-lg p-4">
              <p className="text-yellow-200 text-sm">
                <strong>⚡ Optimization Tip:</strong> Your best hash rate of {formatHashRate(analytics.mining.bestHashRate)} 
                was achieved recently. Try to maintain this performance for maximum rewards.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
} 