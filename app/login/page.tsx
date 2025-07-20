"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet } from "@/lib/wallet";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";

export default function LoginPage() {
  const [recoveryPhrase, setRecoveryPhrase] = useState("");
  const [error, setError] = useState("");
  const [isClient, setIsClient] = useState(false);
  const [hasExistingWallet, setHasExistingWallet] = useState(false);
  const { unlock, loading } = useWallet();
  const router = useRouter();

  // Client-side check to prevent SSR issues
  useEffect(() => {
    setIsClient(true);
    setHasExistingWallet(hasWallet());
  }, []);

  // Redirect if no wallet exists (only after client-side check)
  useEffect(() => {
    if (isClient && !hasExistingWallet) {
      router.push("/onboarding");
    }
  }, [isClient, hasExistingWallet, router]);

  // Don't render anything until client-side check is complete
  if (!isClient) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
        <div className="w-full max-w-md">
          <Card className="text-center">
            <CardContent className="p-8">
              <div className="w-12 h-12 border-4 border-white/20 border-t-white/60 rounded-full animate-spin mx-auto mb-4"></div>
              <p className="text-white/70">Loading...</p>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // Don't render login form if no wallet exists
  if (!hasExistingWallet) {
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
      // Unlock the wallet context with recovery phrase
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
        <Card className="text-center">
          <CardHeader>
            <div className="w-20 h-20 glass-card mx-auto mb-6 flex items-center justify-center">
              <span className="text-3xl">🔐</span>
            </div>
            <CardTitle className="text-3xl mb-2">Welcome Back</CardTitle>
            <CardDescription>Enter your recovery phrase to unlock your wallet</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleLogin} className="space-y-6">
              <div>
                <label htmlFor="recoveryPhrase" className="block text-sm font-medium text-white/90 mb-2">
                  Recovery Phrase
                </label>
                <Textarea
                  id="recoveryPhrase"
                  value={recoveryPhrase}
                  onChange={(e) => setRecoveryPhrase(e.target.value)}
                  className="w-full h-24 resize-none"
                  placeholder="Enter your 12-word recovery phrase"
                  disabled={loading}
                  autoFocus
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

            <div className="mt-8 pt-6 border-t border-white/20">
              <p className="text-sm text-white/60 mb-4">
                Don't have a wallet or want to create a new one?
              </p>
              <Button
                onClick={handleCreateNewWallet}
                variant="outline"
                className="w-full"
              >
                Create New Wallet
              </Button>
            </div>

            <div className="mt-6 p-4 rounded-md bg-blue-500/10 border border-blue-500/30">
              <p className="text-sm text-blue-200">
                💡 Keep your recovery phrase safe and secret. Anyone with these words can access your wallet.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 