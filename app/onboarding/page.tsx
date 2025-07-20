"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { generateMnemonic, encryptAndStore } from "@/lib/wallet";

export default function OnboardingPage() {
  const [step, setStep] = useState<"choice" | "create" | "import" | "confirm" | "password">("choice");
  const [mnemonic, setMnemonic] = useState("");
  const [importMnemonic, setImportMnemonic] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const router = useRouter();

  const handleCreateWallet = () => {
    const newMnemonic = generateMnemonic();
    setMnemonic(newMnemonic);
    setStep("confirm");
  };

  const handleImportWallet = () => {
    setStep("import");
  };

  const handleConfirmImport = () => {
    if (!importMnemonic.trim() || importMnemonic.trim().split(' ').length !== 12) {
      setError("Please enter a valid 12-word recovery phrase");
      return;
    }
    setMnemonic(importMnemonic.trim());
    setStep("password");
  };

  const handleConfirmMnemonic = () => {
    setStep("password");
  };

  const handleSetPassword = () => {
    if (password !== confirmPassword) {
      setError("Passwords do not match");
      return;
    }

    if (password.length < 1) {
      setError("Please enter a password");
      return;
    }

    try {
      encryptAndStore(mnemonic, password);
      router.push("/dashboard");
    } catch (err) {
      setError("Failed to create wallet. Please try again.");
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
      <div className="w-full max-w-md">
        <div className="glass-card text-center">
          <div className="mb-8">
            <h1 className="text-3xl font-bold gradient-text mb-2">Welcome to Numi Wallet</h1>
            <p className="text-white/80">Let's set up your secure wallet</p>
          </div>

          {step === "choice" && (
            <div className="space-y-6">
              <div className="text-center">
                <div className="w-20 h-20 glass-card mx-auto mb-6 flex items-center justify-center">
                  <span className="text-3xl">🔐</span>
                </div>
                <p className="text-white/70 mb-6">
                  Choose how you'd like to set up your wallet
                </p>
                <div className="space-y-4">
                  <button
                    onClick={handleCreateWallet}
                    className="glass-button touch-target w-full"
                  >
                    Create New Wallet
                  </button>
                  <button
                    onClick={handleImportWallet}
                    className="glass-button-secondary touch-target w-full"
                  >
                    Import Existing Wallet
                  </button>
                </div>
              </div>
            </div>
          )}

          {step === "import" && (
            <div className="space-y-6">
              <div>
                <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                  <span className="text-2xl">📥</span>
                </div>
                <h2 className="text-xl font-semibold text-white/90 mb-4">Import Your Wallet</h2>
                <p className="text-sm text-white/70 mb-6">
                  Enter your 12-word recovery phrase to restore your wallet.
                </p>
                <div>
                  <label htmlFor="importMnemonic" className="block text-sm font-medium text-white/90 mb-2">
                    Recovery Phrase
                  </label>
                  <textarea
                    id="importMnemonic"
                    value={importMnemonic}
                    onChange={(e) => setImportMnemonic(e.target.value)}
                    className="glass-input w-full touch-target h-24 resize-none"
                    placeholder="Enter your 12-word recovery phrase"
                  />
                </div>
                
                {error && (
                  <div className="glass-card bg-red-500/20 border-red-500/30 text-red-200">
                    {error}
                  </div>
                )}

                <div className="glass-card bg-blue-500/10 border-blue-500/30">
                  <p className="text-sm text-blue-200">
                    💡 Make sure to enter all 12 words in the correct order, separated by spaces.
                  </p>
                </div>

                <div className="flex gap-4">
                  <button
                    onClick={() => setStep("choice")}
                    className="glass-button-secondary touch-target flex-1"
                  >
                    Back
                  </button>
                  <button
                    onClick={handleConfirmImport}
                    className="glass-button touch-target flex-1"
                  >
                    Import Wallet
                  </button>
                </div>
              </div>
            </div>
          )}

          {step === "create" && (
            <div className="space-y-6">
              <div className="text-center">
                <div className="w-20 h-20 glass-card mx-auto mb-6 flex items-center justify-center">
                  <span className="text-3xl">🔐</span>
                </div>
                <p className="text-white/70 mb-6">
                  Create a new wallet to get started with secure cryptocurrency management.
                </p>
                <button
                  onClick={handleCreateWallet}
                  className="glass-button touch-target w-full"
                >
                  Create New Wallet
                </button>
              </div>
            </div>
          )}

          {step === "confirm" && (
            <div className="space-y-6">
              <div>
                <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                  <span className="text-2xl">📝</span>
                </div>
                <h2 className="text-xl font-semibold text-white/90 mb-4">Backup Your Wallet</h2>
                <p className="text-sm text-white/70 mb-6">
                  Write down these 12 words in a secure location. You'll need them to recover your wallet.
                </p>
                <div className="glass-card bg-white/5 p-4 mb-6">
                  <p className="text-sm font-mono text-white/80 break-words leading-relaxed">
                    {mnemonic}
                  </p>
                </div>
                <div className="glass-card bg-yellow-500/10 border-yellow-500/30 mb-6">
                  <p className="text-sm text-yellow-200">
                    ⚠️ Keep this phrase safe and secret. Anyone with these words can access your wallet.
                  </p>
                </div>
                <button
                  onClick={handleConfirmMnemonic}
                  className="glass-button touch-target w-full"
                >
                  I've Written Down My Recovery Phrase
                </button>
              </div>
            </div>
          )}

          {step === "password" && (
            <div className="space-y-6">
              <div>
                <div className="w-16 h-16 glass-card mx-auto mb-4 flex items-center justify-center">
                  <span className="text-2xl">🔒</span>
                </div>
                <h2 className="text-xl font-semibold text-white/90 mb-4">Set Your Password</h2>
                <p className="text-sm text-white/70 mb-6">
                  Create a strong password to protect your wallet.
                </p>
              </div>
              
              <div className="space-y-4">
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
                  />
                </div>
                
                <div>
                  <label htmlFor="confirmPassword" className="block text-sm font-medium text-white/90 mb-2">
                    Confirm Password
                  </label>
                  <input
                    type="password"
                    id="confirmPassword"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="glass-input w-full touch-target"
                    placeholder="Confirm your password"
                  />
                  
                  {/* Password Match Indicator */}
                  {confirmPassword && (
                    <div className="mt-2 text-xs">
                      {password === confirmPassword ? (
                        <span className="text-green-300">✓ Passwords match</span>
                      ) : (
                        <span className="text-red-300">✗ Passwords don't match</span>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {error && (
                <div className="glass-card bg-red-500/20 border-red-500/30 text-red-200">
                  {error}
                </div>
              )}

              <div className="glass-card bg-blue-500/10 border-blue-500/30">
                <p className="text-sm text-blue-200">
                  💡 Choose a password you'll remember to protect your wallet.
                </p>
              </div>

              <button
                onClick={handleSetPassword}
                disabled={!password || password !== confirmPassword}
                className="glass-button touch-target w-full disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Create Wallet
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
} 