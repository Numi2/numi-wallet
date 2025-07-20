"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useWallet } from "@/context/WalletContext";

export default function LoginPage() {
  const [isClient, setIsClient] = useState(false);
  const [recoveryPhrase, setRecoveryPhrase] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const { unlockWallet, isLocked } = useWallet();
  const router = useRouter();

  useEffect(() => {
    setIsClient(true);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError("");

    try {
      await unlockWallet("numicoin");
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to unlock wallet");
    } finally {
      setIsLoading(false);
    }
  };

  const handleBack = () => {
    router.push("/");
  };

  if (!isClient) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardContent className="p-8 text-center">
            <div className="w-12 h-12 border-4 border-primary/20 border-t-primary rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-muted-foreground">Loading...</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="space-y-4">
          <div className="text-center">
            <div className="w-16 h-16 bg-gradient-to-br from-primary to-primary/60 rounded-2xl mx-auto mb-4 flex items-center justify-center">
              <span className="text-2xl">🔐</span>
            </div>
            <CardTitle className="text-2xl">Unlock Wallet</CardTitle>
            <CardDescription>
              Enter your recovery phrase to access your NumiCoin wallet
            </CardDescription>
          </div>
        </CardHeader>

        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="recoveryPhrase">Recovery Phrase</Label>
              <Textarea
                id="recoveryPhrase"
                value={recoveryPhrase}
                onChange={(e) => setRecoveryPhrase(e.target.value)}
                placeholder="Enter your 12-word recovery phrase"
                className="min-h-[120px] resize-none"
                disabled={isLoading}
              />
              <p className="text-xs text-muted-foreground">
                Enter all 12 words in order, separated by spaces
              </p>
            </div>

            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            <div className="space-y-3">
              <Button
                type="submit"
                disabled={isLoading || recoveryPhrase.trim().split(' ').length !== 12}
                className="w-full"
              >
                {isLoading ? "Unlocking..." : "Unlock Wallet"}
              </Button>
              
              <Button
                type="button"
                variant="outline"
                onClick={handleBack}
                className="w-full"
                disabled={isLoading}
              >
                Back to Home
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
} 