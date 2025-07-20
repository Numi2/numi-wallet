"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { hasWallet } from "@/lib/wallet";

export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    // Check if wallet exists and redirect accordingly
    const walletExists = hasWallet();
    
    if (walletExists) {
      router.push("/login");
    } else {
      router.push("/onboarding");
    }
  }, [router]);

  // Show loading state while redirecting
  return (
    <div className="min-h-screen flex items-center justify-center p-4 liquid-bg">
      <div className="text-center">
        <div className="glass-card p-8">
          <div className="w-16 h-16 border-4 border-white/20 border-t-white/60 rounded-full animate-spin mx-auto mb-6"></div>
          <h2 className="text-xl font-semibold gradient-text mb-2">Loading Numi Wallet</h2>
          <p className="text-white/70">Preparing your secure wallet experience...</p>
        </div>
      </div>
    </div>
  );
}
