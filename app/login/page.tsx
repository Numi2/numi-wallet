"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet, loadWallet } from "@/lib/wallet";

export default function LoginPage() {
  const [recoveryPhrase, setRecoveryPhrase] = useState("");
  const [error, setError] = useState("");
  const { unlock, loading } = useWallet();
  const router = useRouter();

  // Redirect if no wallet exists
  if (!hasWallet()) {
    router.push("/onboarding");
    return null;
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    
    // Validate recovery phrase
    const words = recoveryPhrase.trim().split(' ');
    if (words.length !== 12) {
      setError("Please enter your complete 12-word recovery phrase");
      return;
    }
    
    try {
      // Try to load wallet from recovery phrase
      const wallet = loadWallet(recoveryPhrase.trim());
      
      // If successful, unlock the wallet context
      await unlock(recoveryPhrase.trim());
      router.push("/dashboard");
    } catch (err) {
      setError("Invalid recovery phrase. Please check your 12 words and try again.");
    }
  };

  const handleCreateNewWallet = () => {
    // Clear existing wallet and redirect to onboarding
    if (typeof window !== "undefined") {
      localStorage.removeItem("numi_wallet_encrypted");
    }
    router.push("/onboarding");
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
      <div className="w-full max-w-md">
        <div className="glass-card text-center">
          <div className="mb-8">
            <div className="w-20 h-20 glass-card mx-auto mb-6 flex items-center justify-center">
              <span className="text-3xl">🔐</span>
            </div>
            <h1 className="text-3xl font-bold gradient-text mb-2">Welcome Back</h1>
            <p className="text-white/80">Enter your recovery phrase to unlock your wallet</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-6">
            <div>
              <label htmlFor="recoveryPhrase" className="block text-sm font-medium text-white/90 mb-2">
                Recovery Phrase
              </label>
              <textarea
                id="recoveryPhrase"
                value={recoveryPhrase}
                onChange={(e) => setRecoveryPhrase(e.target.value)}
                className="glass-input w-full touch-target h-24 resize-none"
                placeholder="Enter your 12-word recovery phrase"
                disabled={loading}
                autoFocus
              />
              <p className="text-xs text-white/60 mt-2">
                Enter all 12 words in order, separated by spaces
              </p>
            </div>

            {error && (
              <div className="glass-card bg-red-500/20 border-red-500/30 text-red-200">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading || recoveryPhrase.trim().split(' ').length !== 12}
              className="glass-button w-full touch-target disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "Unlocking..." : "Unlock Wallet"}
            </button>
          </form>

          <div className="mt-8 pt-6 border-t border-white/20">
            <p className="text-sm text-white/60 mb-4">
              Don't have a wallet or want to create a new one?
            </p>
            <button
              onClick={handleCreateNewWallet}
              className="glass-button-secondary w-full touch-target text-sm"
            >
              Create New Wallet
            </button>
          </div>

          <div className="mt-6 glass-card bg-blue-500/10 border-blue-500/30">
            <p className="text-sm text-blue-200">
              💡 Keep your recovery phrase safe and secret. Anyone with these words can access your wallet.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
} 