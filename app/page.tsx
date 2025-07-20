"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { hasWallet } from "@/lib/wallet";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export default function HomePage() {
  const [isClient, setIsClient] = useState(false);
  const [hasExistingWallet, setHasExistingWallet] = useState(false);
  const router = useRouter();

  useEffect(() => {
    setIsClient(true);
    setHasExistingWallet(hasWallet());
  }, []);

  const handleCreateNewWallet = () => {
    router.push("/onboarding");
  };

  const handleImportWallet = () => {
    router.push("/login");
  };

  // Show loading state while checking wallet status
  if (!isClient) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
        <Card className="text-center">
          <CardContent className="p-8">
            <div className="w-12 h-12 border-4 border-white/20 border-t-white/60 rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-white/70">Loading Numi Wallet...</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
      <div className="w-full max-w-md">
        <Card className="text-center">
          <CardHeader>
            <div className="w-24 h-24 glass-card mx-auto mb-6 flex items-center justify-center">
              <span className="text-4xl">🌟</span>
            </div>
            <CardTitle className="text-3xl mb-2">Welcome to NumiCoin</CardTitle>
            <CardDescription className="text-lg">
              The People's Coin - Easy to Mine, Fair to Earn
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* People's Coin Banner */}
            <div className="p-4 rounded-md bg-gradient-to-r from-green-500/20 to-blue-500/20 border border-green-500/30">
              <p className="text-sm text-green-200">
                💎 No initial distributions - earn your coins through honest mining work!
              </p>
            </div>

            {/* Wallet Options */}
            <div className="space-y-4">
              <Button
                onClick={handleCreateNewWallet}
                size="lg"
                className="w-full h-16 text-lg font-semibold"
              >
                🔐 Create New Wallet
              </Button>
              
              <Button
                onClick={handleImportWallet}
                variant="outline"
                size="lg"
                className="w-full h-16 text-lg font-semibold"
              >
                📥 Import Existing Wallet
              </Button>
            </div>

            {/* Features */}
            <div className="space-y-3 text-left">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-green-500/20 rounded-full flex items-center justify-center">
                  <span className="text-green-400 text-sm">✓</span>
                </div>
                <span className="text-white/80">Easy mining for everyone</span>
              </div>
              
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-blue-500/20 rounded-full flex items-center justify-center">
                  <span className="text-blue-400 text-sm">✓</span>
                </div>
                <span className="text-white/80">Democratic governance</span>
              </div>
              
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-purple-500/20 rounded-full flex items-center justify-center">
                  <span className="text-purple-400 text-sm">✓</span>
                </div>
                <span className="text-white/80">Secure and transparent</span>
              </div>
            </div>

            {/* Info */}
            <div className="p-4 rounded-md bg-blue-500/10 border border-blue-500/30">
              <p className="text-sm text-blue-200">
                💡 Choose "Create New Wallet" if you're new to NumiCoin, or "Import Existing Wallet" if you already have a recovery phrase.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
