"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { hasWallet } from "@/lib/wallet";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";

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

  if (!isClient) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ background: 'linear-gradient(135deg, rgba(15, 15, 35, 0.9) 0%, rgba(26, 26, 46, 0.95) 100%)' }}>
        <Card className="w-full max-w-md">
          <CardContent className="p-8 text-center">
            <div className="w-12 h-12 border-4 border-blue-500/20 border-t-blue-500 rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-white">Loading NumiCoin...</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 md:p-8" style={{ 
      background: 'linear-gradient(135deg, rgba(15, 15, 35, 0.8) 0%, rgba(26, 26, 46, 0.9) 100%), url("/dong-zhang-ILYVeUgPkmI-unsplash.jpg") no-repeat center center fixed',
      backgroundSize: 'cover',
      backgroundAttachment: 'fixed'
    }}>
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-4">
          <div className="text-4xl mb-4">🌟</div>
          <h1 className="text-4xl md:text-6xl font-bold text-white mb-4">
            NumiCoin
          </h1>
          <p className="text-xl md:text-2xl text-blue-200 font-semibold">
            The People's Coin - Easy to Mine, Fair to Earn
          </p>
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
          {/* Left Side - Features */}
          <div className="space-y-6">
            <Card className="bg-white/10 backdrop-blur-xl border-white/20">
              <CardContent className="p-6">
                <div className="flex items-center gap-3 mb-4">
                  <span className="text-2xl">💎</span>
                  <h3 className="text-lg font-semibold text-white">No Initial Distributions</h3>
                </div>
                <p className="text-blue-100">Earn your coins through honest mining work - no airdrops, no pre-mines.</p>
              </CardContent>
            </Card>

            <Separator className="bg-white/20" />

            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <span className="text-green-400 text-xl">✓</span>
                <span className="text-white text-lg">Easy mining for everyone</span>
              </div>
              <div className="flex items-center gap-3">
                <span className="text-green-400 text-xl">✓</span>
                <span className="text-white text-lg">Democratic governance</span>
              </div>
              <div className="flex items-center gap-3">
                <span className="text-green-400 text-xl">✓</span>
                <span className="text-white text-lg">Secure and transparent</span>
              </div>
            </div>
          </div>

          {/* Right Side - Wallet Options */}
          <div className="space-y-6">
            <Card className="bg-white/10 backdrop-blur-xl border-white/20">
              <CardHeader>
                <CardTitle className="text-white text-2xl">Get Started</CardTitle>
                <CardDescription className="text-blue-200">
                  Choose how you want to access your NumiCoin wallet
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <Button
                  onClick={handleCreateNewWallet}
                  className="w-full h-16 text-lg font-semibold bg-blue-600 hover:bg-blue-700 text-white border-0"
                >
                  <span className="text-2xl mr-3">🆕</span>
                  Create New Wallet
                </Button>
                
                <Button
                  onClick={handleImportWallet}
                  variant="outline"
                  className="w-full h-16 text-lg font-semibold border-white/30 text-white hover:bg-white/10"
                >
                  <span className="text-2xl mr-3">📥</span>
                  Import Existing Wallet
                </Button>
              </CardContent>
            </Card>

            <Card className="bg-gradient-to-r from-blue-500/20 to-purple-500/20 border-blue-500/30">
              <CardContent className="p-6">
                <h3 className="text-xl font-semibold text-white mb-3">Why Choose NumiCoin?</h3>
                <div className="space-y-2 text-blue-100">
                  <p>• <strong>Accessible:</strong> Mine on any device with a browser</p>
                  <p>• <strong>Fair:</strong> No initial distributions - earn through work</p>
                  <p>• <strong>Democratic:</strong> Staking-based governance</p>
                  <p>• <strong>Secure:</strong> Built on proven blockchain technology</p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Bottom Info */}
        <Card className="bg-yellow-500/20 border-yellow-500/30">
          <CardContent className="p-6">
            <div className="flex items-start gap-3">
              <span className="text-2xl">💡</span>
              <div>
                <p className="text-white">
                  <strong>New to NumiCoin?</strong> Choose "Create New Wallet" to generate a new wallet with a recovery phrase. 
                  <strong>Already have a wallet?</strong> Choose "Import Existing Wallet" and enter your recovery phrase to restore your wallet.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Footer */}
        <div className="text-center text-blue-200">
          <p className="text-sm">
            NumiCoin - The People's Coin • Easy to Mine • Fair to Earn
          </p>
        </div>
      </div>
    </div>
  );
}
