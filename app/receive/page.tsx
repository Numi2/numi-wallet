"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet, formatAddress } from "@/lib/wallet";

export default function ReceivePage() {
  const { wallet } = useWallet();
  const [copied, setCopied] = useState(false);
  const [canShare, setCanShare] = useState(false);
  const router = useRouter();

  useEffect(() => {
    // Check if wallet exists, if not redirect to onboarding
    if (!hasWallet()) {
      router.push("/onboarding");
    }
    
    // Check if Web Share API is available
    if (typeof navigator !== 'undefined' && 'share' in navigator) {
      setCanShare(true);
    }
  }, [router]);

  const copyAddress = async () => {
    if (wallet?.address) {
      try {
        await navigator.clipboard.writeText(wallet.address);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } catch (err) {
        console.error("Failed to copy address:", err);
      }
    }
  };

  const shareAddress = async () => {
    if (wallet?.address && navigator.share) {
      try {
        await navigator.share({
          title: "My Ethereum Address",
          text: `Send ETH to: ${wallet.address}`,
          url: wallet.address,
        });
      } catch (err) {
        console.error("Failed to share address:", err);
      }
    }
  };

  // Simple QR code generation using a service
  const generateQRCode = (text: string) => {
    return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(text)}`;
  };

  if (!wallet) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-white/20 border-t-white/60 rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-white/70">Loading wallet...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-2xl mx-auto">
        <div className="glass-card">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold gradient-text">Receive ETH</h1>
              <p className="text-white/70 mt-1">Share your address to receive cryptocurrency</p>
            </div>
            <button
              onClick={() => router.push("/dashboard")}
              className="glass-button-secondary touch-target"
            >
              ← Back
            </button>
          </div>

          <div className="text-center space-y-8">
            {/* QR Code */}
            <div className="glass-card bg-white/5 p-8">
              <img
                src={generateQRCode(wallet.address)}
                alt="QR Code"
                className="mx-auto rounded-2xl shadow-2xl"
                width="200"
                height="200"
              />
            </div>

            {/* Address Display */}
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-white/90 mb-3">
                  Your Ethereum Address
                </label>
                <div className="glass-card bg-white/5 p-4">
                  <p className="text-sm font-mono text-white/80 break-all">
                    {wallet.address}
                  </p>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex flex-col sm:flex-row gap-4">
                <button
                  onClick={copyAddress}
                  className="glass-button touch-target flex-1"
                >
                  {copied ? "Copied!" : "Copy Address"}
                </button>
                {canShare && (
                  <button
                    onClick={shareAddress}
                    className="glass-button-secondary touch-target flex-1"
                  >
                    Share
                  </button>
                )}
              </div>
            </div>

            {/* Instructions */}
            <div className="glass-card bg-blue-500/10 border-blue-500/30">
              <h3 className="text-sm font-medium text-blue-300 mb-3">How to receive ETH</h3>
              <ul className="text-sm text-blue-200 space-y-2">
                <li>• Share your address with the sender</li>
                <li>• They can scan the QR code or copy the address</li>
                <li>• Once sent, the transaction will appear in your history</li>
                <li>• Only send ETH to this address (not other tokens)</li>
              </ul>
            </div>

            {/* Security Warning */}
            <div className="glass-card bg-yellow-500/10 border-yellow-500/30">
              <h3 className="text-sm font-medium text-yellow-300 mb-3">Security Tips</h3>
              <ul className="text-sm text-yellow-200 space-y-2">
                <li>• Only share this address with trusted parties</li>
                <li>• Double-check the address before sending</li>
                <li>• Never share your private key or recovery phrase</li>
                <li>• This address can receive ETH from any network</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
} 