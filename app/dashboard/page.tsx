"use client";

import { useEffect, useState } from "react";
import { useWallet } from "@/context/WalletContext";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { useRouter } from "next/navigation";

export default function DashboardPage() {
  const { wallet, balance, isLocked, unlockWallet, lockWallet } = useWallet();
  const [isClient, setIsClient] = useState(false);
  const router = useRouter();

  useEffect(() => {
    setIsClient(true);
  }, []);

  const handleMine = () => {
    router.push("/miner");
  };

  const handleStake = () => {
    router.push("/stake");
  };

  const handleGovernance = () => {
    router.push("/governance");
  };

  const handleSend = () => {
    router.push("/send");
  };

  const handleReceive = () => {
    router.push("/receive");
  };

  if (!isClient) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardContent className="p-8 text-center">
            <div className="w-12 h-12 border-4 border-primary/20 border-t-primary rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-muted-foreground">Loading Dashboard...</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (isLocked) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-center">Wallet Locked</CardTitle>
            <CardDescription className="text-center">
              Please unlock your wallet to access the dashboard
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button onClick={() => router.push("/login")} className="w-full">
              Unlock Wallet
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
          <p className="text-muted-foreground">Welcome to your NumiCoin wallet</p>
        </div>
        <Button variant="outline" onClick={lockWallet}>
          Lock Wallet
        </Button>
      </div>

      {/* Balance Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <span>💰</span>
            NUMI Balance
          </CardTitle>
          <CardDescription>Your current NumiCoin balance</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold text-foreground">
            {balance ? `${balance.toFixed(2)} NUMI` : "0.00 NUMI"}
          </div>
          <Badge variant="secondary" className="mt-2">
            The People's Coin
          </Badge>
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle>Quick Actions</CardTitle>
          <CardDescription>Access your wallet features</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4">
            <Button onClick={handleMine} className="h-20 flex flex-col gap-2">
              <span className="text-2xl">⛏️</span>
              <span>Mine NUMI</span>
            </Button>
            
            <Button onClick={handleStake} variant="outline" className="h-20 flex flex-col gap-2">
              <span className="text-2xl">🔒</span>
              <span>Stake & Vote</span>
            </Button>
            
            <Button onClick={handleSend} variant="outline" className="h-20 flex flex-col gap-2">
              <span className="text-2xl">📤</span>
              <span>Send NUMI</span>
            </Button>
            
            <Button onClick={handleReceive} variant="outline" className="h-20 flex flex-col gap-2">
              <span className="text-2xl">📥</span>
              <span>Receive NUMI</span>
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Governance Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <span>🗳️</span>
            Governance
          </CardTitle>
          <CardDescription>Participate in community decisions</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-3 rounded-lg bg-muted/50">
              <span className="text-foreground">Voting Power</span>
              <Badge variant="outline">Based on staked NUMI</Badge>
            </div>
            <Button onClick={handleGovernance} className="w-full">
              View Proposals
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Wallet Info */}
      <Card>
        <CardHeader>
          <CardTitle>Wallet Information</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Address</span>
              <span className="font-mono text-sm text-foreground">
                {wallet?.address ? `${wallet.address.slice(0, 6)}...${wallet.address.slice(-4)}` : "Not connected"}
              </span>
            </div>
            <Separator />
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Network</span>
              <Badge variant="secondary">Ethereum</Badge>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
} 