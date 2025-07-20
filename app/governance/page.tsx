"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet } from "@/lib/wallet";

interface Proposal {
  id: number;
  proposer: string;
  description: string;
  forVotes: string;
  againstVotes: string;
  startTime: number;
  endTime: number;
  executed: boolean;
  canceled: boolean;
  hasVoted?: boolean;
  userVote?: boolean;
}

export default function GovernancePage() {
  const { 
    wallet, 
    isLocked,
    miningStats
  } = useWallet();
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [newProposal, setNewProposal] = useState("");
  const [loading, setLoading] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [userVotingPower, setUserVotingPower] = useState("0");
  const [userStakedAmount, setUserStakedAmount] = useState("0");
  const [governanceThreshold, setGovernanceThreshold] = useState("1000");
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

    // Load governance data
    loadGovernanceData();
  }, [router, isLocked]);

  const loadGovernanceData = async () => {
    if (!wallet) return;
    
    try {
      // Mock data - replace with actual contract calls
      const mockProposals: Proposal[] = [
        {
          id: 1,
          proposer: "0x1234...5678",
          description: "Increase mining rewards from 100 to 150 NUMI per block",
          forVotes: "50000",
          againstVotes: "15000",
          startTime: Math.floor(Date.now() / 1000) - 86400, // 1 day ago
          endTime: Math.floor(Date.now() / 1000) + 6 * 86400, // 6 days from now
          executed: false,
          canceled: false,
          hasVoted: false
        },
        {
          id: 2,
          proposer: "0x8765...4321",
          description: "Reduce staking APY from 5% to 4% to control inflation",
          forVotes: "25000",
          againstVotes: "45000",
          startTime: Math.floor(Date.now() / 1000) - 2 * 86400,
          endTime: Math.floor(Date.now() / 1000) + 5 * 86400,
          executed: false,
          canceled: false,
          hasVoted: true,
          userVote: false
        },
        {
          id: 3,
          proposer: "0x1111...2222",
          description: "Add new mining pool with 3% fee structure",
          forVotes: "75000",
          againstVotes: "10000",
          startTime: Math.floor(Date.now() / 1000) - 7 * 86400,
          endTime: Math.floor(Date.now() / 1000),
          executed: true,
          canceled: false,
          hasVoted: true,
          userVote: true
        }
      ];

      setProposals(mockProposals);
      setUserVotingPower("2500"); // Mock staked amount (voting power)
      setUserStakedAmount("2500"); // Mock staked amount
    } catch (error) {
      console.error("Failed to load governance data:", error);
    }
  };

  const handleCreateProposal = async () => {
    if (!wallet || !newProposal.trim()) return;
    
    setLoading(true);
    try {
      // This would be replaced with actual contract call
      console.log("Creating proposal:", newProposal);
      
      // Simulate transaction
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      setShowCreateModal(false);
      setNewProposal("");
      await loadGovernanceData();
    } catch (error) {
      console.error("Failed to create proposal:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleVote = async (proposalId: number, support: boolean) => {
    if (!wallet) return;
    
    setLoading(true);
    try {
      // This would be replaced with actual contract call
      console.log("Voting on proposal", proposalId, "support:", support);
      
      // Simulate transaction
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      await loadGovernanceData();
    } catch (error) {
      console.error("Failed to vote:", error);
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (timestamp: number): string => {
    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString() + " " + date.toLocaleTimeString();
  };

  const getProposalStatus = (proposal: Proposal): string => {
    const now = Math.floor(Date.now() / 1000);
    
    if (proposal.canceled) return "Canceled";
    if (proposal.executed) return "Executed";
    if (now < proposal.startTime) return "Pending";
    if (now > proposal.endTime) return "Ended";
    return "Active";
  };

  const getProposalStatusColor = (status: string): string => {
    switch (status) {
      case "Active": return "text-green-400";
      case "Pending": return "text-yellow-400";
      case "Ended": return "text-gray-400";
      case "Executed": return "text-blue-400";
      case "Canceled": return "text-red-400";
      default: return "text-white/60";
    }
  };

  const canCreateProposal = (): boolean => {
    return parseFloat(userStakedAmount) >= parseFloat(governanceThreshold);
  };

  const getVotingProgress = (proposal: Proposal): number => {
    const totalVotes = parseFloat(proposal.forVotes) + parseFloat(proposal.againstVotes);
    if (totalVotes === 0) return 0;
    return (parseFloat(proposal.forVotes) / totalVotes) * 100;
  };

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div className="glass-card">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold gradient-text">Governance</h1>
              <p className="text-white/70 mt-1">Participate in NumiCoin ecosystem decisions</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => router.push("/dashboard")}
                className="glass-button-secondary touch-target text-sm"
              >
                Back to Dashboard
              </button>
              <button
                onClick={() => setShowCreateModal(true)}
                disabled={!canCreateProposal()}
                className="glass-button touch-target text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Create Proposal
              </button>
            </div>
          </div>
        </div>

        {/* Governance Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Your Voting Power</h4>
            <p className="text-2xl font-bold gradient-text">
              {parseFloat(userVotingPower).toLocaleString()} NUMI
            </p>
            <p className="text-xs text-white/50 mt-1">Based on staked tokens</p>
          </div>
          
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Staked Amount</h4>
            <p className="text-2xl font-bold gradient-text">
              {parseFloat(userStakedAmount).toLocaleString()} NUMI
            </p>
            <p className="text-xs text-white/50 mt-1">Currently staked</p>
          </div>
          
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Proposal Threshold</h4>
            <p className="text-2xl font-bold gradient-text">
              {parseFloat(governanceThreshold).toLocaleString()} NUMI
            </p>
            <p className="text-xs text-white/50 mt-1">Staked tokens required</p>
          </div>
          
          <div className="glass-card">
            <h4 className="text-sm font-medium text-white/70 mb-2">Active Proposals</h4>
            <p className="text-2xl font-bold gradient-text">
              {proposals.filter(p => getProposalStatus(p) === "Active").length}
            </p>
          </div>
        </div>

        {/* Staking Notice */}
        {parseFloat(userStakedAmount) === 0 && (
          <div className="glass-card bg-yellow-500/20 border border-yellow-500/30">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 glass-card flex items-center justify-center">
                <span className="text-yellow-300">⚠️</span>
              </div>
              <div>
                <h4 className="font-semibold text-yellow-200">No Voting Power</h4>
                <p className="text-yellow-100 text-sm">
                  You need to stake NUMI tokens to participate in governance. 
                  <button 
                    onClick={() => router.push("/stake")}
                    className="underline ml-1 hover:text-yellow-300"
                  >
                    Stake tokens now
                  </button>
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Proposals List */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-6">Proposals</h3>
          
          {proposals.length === 0 ? (
            <div className="text-center py-12">
              <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                <span className="text-2xl">📋</span>
              </div>
              <p className="text-white/70 text-lg mb-2">No proposals yet</p>
              <p className="text-white/50">Be the first to create a proposal!</p>
            </div>
          ) : (
            <div className="space-y-4">
              {proposals.map((proposal) => (
                <div key={proposal.id} className="glass-card bg-white/5 hover:bg-white/10 transition-all duration-200">
                  <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-sm font-medium text-white/60">#{proposal.id}</span>
                        <span className={`px-3 py-1 rounded-full text-xs font-medium ${getProposalStatusColor(getProposalStatus(proposal))}`}>
                          {getProposalStatus(proposal)}
                        </span>
                        {proposal.hasVoted && (
                          <span className="px-2 py-1 rounded-full text-xs bg-blue-500/20 text-blue-300">
                            Voted {proposal.userVote ? "✓" : "✗"}
                          </span>
                        )}
                      </div>
                      
                      <h4 className="text-lg font-semibold text-white/90 mb-2">
                        {proposal.description}
                      </h4>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-white/70">
                        <div>
                          <span className="text-white/50">Proposed by:</span> {proposal.proposer}
                        </div>
                        <div>
                          <span className="text-white/50">Voting ends:</span> {formatTime(proposal.endTime)}
                        </div>
                      </div>
                      
                      {/* Voting Progress */}
                      <div className="mt-4">
                        <div className="flex justify-between text-sm text-white/60 mb-2">
                          <span>For: {parseFloat(proposal.forVotes).toLocaleString()} NUMI</span>
                          <span>Against: {parseFloat(proposal.againstVotes).toLocaleString()} NUMI</span>
                        </div>
                        <div className="w-full bg-white/10 rounded-full h-2">
                          <div 
                            className="bg-green-500 h-2 rounded-full transition-all duration-300"
                            style={{ width: `${getVotingProgress(proposal)}%` }}
                          />
                        </div>
                      </div>
                    </div>
                    
                    {/* Voting Actions */}
                    {getProposalStatus(proposal) === "Active" && !proposal.hasVoted && parseFloat(userVotingPower) > 0 && (
                      <div className="flex flex-col gap-2 lg:flex-shrink-0">
                        <button
                          onClick={() => handleVote(proposal.id, true)}
                          disabled={loading}
                          className="glass-button-success touch-target text-sm disabled:opacity-50"
                        >
                          Vote For
                        </button>
                        <button
                          onClick={() => handleVote(proposal.id, false)}
                          disabled={loading}
                          className="glass-button-danger touch-target text-sm disabled:opacity-50"
                        >
                          Vote Against
                        </button>
                      </div>
                    )}
                    
                    {getProposalStatus(proposal) === "Active" && parseFloat(userVotingPower) === 0 && (
                      <div className="text-center text-white/50 text-sm">
                        Stake tokens to vote
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* How Governance Works */}
        <div className="glass-card">
          <h3 className="text-lg font-semibold text-white/90 mb-4">How Governance Works</h3>
          <div className="space-y-4 text-white/80">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="text-center">
                <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                  <span className="text-xl">📝</span>
                </div>
                <h4 className="font-semibold mb-2">Create Proposal</h4>
                <p className="text-sm">Need {parseFloat(governanceThreshold).toLocaleString()} staked NUMI to create proposals</p>
              </div>
              
              <div className="text-center">
                <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                  <span className="text-xl">🗳️</span>
                </div>
                <h4 className="font-semibold mb-2">Vote</h4>
                <p className="text-sm">Voting power equals your staked NUMI amount</p>
              </div>
              
              <div className="text-center">
                <div className="w-12 h-12 glass-card mx-auto mb-3 flex items-center justify-center">
                  <span className="text-xl">⚡</span>
                </div>
                <h4 className="font-semibold mb-2">Execute</h4>
                <p className="text-sm">Winning proposals are executed by the team</p>
              </div>
            </div>
            
            <div className="bg-blue-500/20 border border-blue-500/30 rounded-lg p-4">
              <p className="text-blue-200 text-sm">
                <strong>Staking-Based Governance:</strong> Your voting power is equal to your staked NUMI tokens. 
                Only staked tokens count for governance participation. Unstake tokens to reduce voting power.
              </p>
            </div>
            
            <div className="bg-green-500/20 border border-green-500/30 rounded-lg p-4">
              <p className="text-green-200 text-sm">
                <strong>Mining-Only Token Distribution:</strong> NUMI tokens can only be earned through mining. 
                There are no airdrops, presales, or initial distributions. Fair launch through proof-of-work.
              </p>
            </div>
          </div>
        </div>

        {/* Create Proposal Modal */}
        {showCreateModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
            <div className="glass-card max-w-md w-full">
              <h3 className="text-lg font-semibold text-white/90 mb-4">Create Proposal</h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-white/70 mb-2">
                    Proposal Description
                  </label>
                  <textarea
                    value={newProposal}
                    onChange={(e) => setNewProposal(e.target.value)}
                    placeholder="Describe your proposal..."
                    className="glass-input w-full h-24 resize-none"
                    disabled={loading}
                  />
                  <p className="text-xs text-white/60 mt-1">
                    Minimum {parseFloat(governanceThreshold).toLocaleString()} staked NUMI required
                  </p>
                </div>
                
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowCreateModal(false)}
                    disabled={loading}
                    className="glass-button-secondary flex-1 touch-target"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleCreateProposal}
                    disabled={loading || !newProposal.trim() || !canCreateProposal()}
                    className="glass-button flex-1 touch-target disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? "Creating..." : "Create Proposal"}
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