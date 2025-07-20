"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@/context/WalletContext";
import { hasWallet, isValidAddress, formatAddress, estimateGas, getGasPrice } from "@/lib/wallet";

export default function SendPage() {
  const { wallet, balance, sendTransaction, balanceLoading } = useWallet();
  const [toAddress, setToAddress] = useState("");
  const [amount, setAmount] = useState("");
  const [gasEstimate, setGasEstimate] = useState<string>("");
  const [gasPrice, setGasPrice] = useState<string>("");
  const [estimatedFee, setEstimatedFee] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const router = useRouter();

  useEffect(() => {
    // Check if wallet exists, if not redirect to onboarding
    if (!hasWallet()) {
      router.push("/onboarding");
    }
  }, [router]);

  // Estimate gas when address or amount changes
  useEffect(() => {
    const estimateGasFee = async () => {
      if (!wallet || !toAddress || !amount || !isValidAddress(toAddress) || parseFloat(amount) <= 0) {
        setGasEstimate("");
        setEstimatedFee("");
        return;
      }

      try {
        const gasLimit = await estimateGas(wallet.address, toAddress, amount);
        const currentGasPrice = await getGasPrice();
        
        setGasEstimate(gasLimit.toString());
        setGasPrice(currentGasPrice.toString());
        
        // Calculate estimated fee in ETH
        const feeWei = gasLimit * currentGasPrice;
        const feeEth = (Number(feeWei) / 1e18).toFixed(6);
        setEstimatedFee(feeEth);
      } catch (err) {
        console.error("Error estimating gas:", err);
        setGasEstimate("");
        setEstimatedFee("");
      }
    };

    estimateGasFee();
  }, [wallet, toAddress, amount]);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!wallet) {
      setError("Wallet not loaded");
      return;
    }

    if (!isValidAddress(toAddress)) {
      setError("Invalid recipient address");
      return;
    }

    if (parseFloat(amount) <= 0) {
      setError("Amount must be greater than 0");
      return;
    }

    const totalAmount = parseFloat(amount) + parseFloat(estimatedFee || "0");
    if (totalAmount > balance) {
      setError("Insufficient balance (including gas fees)");
      return;
    }

    setLoading(true);
    setError("");
    setSuccess("");

    try {
      const txHash = await sendTransaction(toAddress, amount);
      setSuccess(`Transaction sent! Hash: ${txHash}`);
      setToAddress("");
      setAmount("");
      setGasEstimate("");
      setEstimatedFee("");
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to send transaction";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleMaxAmount = () => {
    if (!balance || !estimatedFee) return;
    
    const maxAmount = Math.max(0, balance - parseFloat(estimatedFee));
    setAmount(maxAmount.toFixed(6));
  };

  const copyAddress = () => {
    if (wallet?.address) {
      navigator.clipboard.writeText(wallet.address);
      // You could add a toast notification here
    }
  };

  return (
    <div className="min-h-screen p-4 md:p-8 liquid-bg">
      <div className="max-w-2xl mx-auto">
        <div className="glass-card">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold gradient-text">Send ETH</h1>
              <p className="text-white/70 mt-1">Transfer cryptocurrency securely</p>
            </div>
            <button
              onClick={() => router.push("/dashboard")}
              className="glass-button-secondary touch-target"
            >
              ← Back
            </button>
          </div>

          {/* Balance Display */}
          <div className="glass-card bg-white/5 mb-8">
            <div className="flex justify-between items-center">
              <span className="text-sm text-white/70">Available Balance</span>
              <div className="text-right">
                <div className="text-lg font-semibold gradient-text">
                  {balanceLoading ? (
                    <span className="loading-shimmer">Loading...</span>
                  ) : (
                    `${balance.toFixed(6)} ETH`
                  )}
                </div>
                <button
                  onClick={copyAddress}
                  className="text-xs text-white/60 hover:text-white/80 transition-colors"
                >
                  {wallet ? formatAddress(wallet.address) : ""}
                </button>
              </div>
            </div>
          </div>

          {/* Send Form */}
          <form onSubmit={handleSend} className="space-y-6">
            {/* Recipient Address */}
            <div>
              <label htmlFor="toAddress" className="block text-sm font-medium text-white/90 mb-3">
                Recipient Address
              </label>
              <input
                type="text"
                id="toAddress"
                value={toAddress}
                onChange={(e) => setToAddress(e.target.value)}
                className="glass-input w-full touch-target"
                placeholder="0x..."
                disabled={loading}
              />
              {toAddress && !isValidAddress(toAddress) && (
                <p className="text-red-300 text-sm mt-2 glass-card bg-red-500/20 border-red-500/30">
                  Invalid Ethereum address
                </p>
              )}
            </div>

            {/* Amount */}
            <div>
              <label htmlFor="amount" className="block text-sm font-medium text-white/90 mb-3">
                Amount (ETH)
              </label>
              <div className="flex space-x-3">
                <input
                  type="number"
                  id="amount"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  step="0.000001"
                  min="0"
                  className="glass-input flex-1 touch-target"
                  placeholder="0.0"
                  disabled={loading}
                />
                <button
                  type="button"
                  onClick={handleMaxAmount}
                  className="glass-button-secondary touch-target px-4"
                  disabled={loading || !estimatedFee}
                >
                  MAX
                </button>
              </div>
            </div>

            {/* Gas Estimation */}
            {gasEstimate && (
              <div className="glass-card bg-blue-500/10 border-blue-500/30">
                <h3 className="text-sm font-medium text-blue-300 mb-3">Transaction Details</h3>
                <div className="space-y-2 text-sm text-blue-200">
                  <div className="flex justify-between">
                    <span>Gas Limit:</span>
                    <span>{parseInt(gasEstimate).toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Gas Price:</span>
                    <span>{parseInt(gasPrice).toLocaleString()} wei</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Estimated Fee:</span>
                    <span>{estimatedFee} ETH</span>
                  </div>
                  <div className="flex justify-between font-medium text-white border-t border-blue-500/30 pt-2">
                    <span>Total:</span>
                    <span>{(parseFloat(amount || "0") + parseFloat(estimatedFee)).toFixed(6)} ETH</span>
                  </div>
                </div>
              </div>
            )}

            {/* Error/Success Messages */}
            {error && (
              <div className="glass-card bg-red-500/20 border-red-500/30 text-red-200">
                {error}
              </div>
            )}

            {success && (
              <div className="glass-card bg-green-500/20 border-green-500/30 text-green-200">
                {success}
              </div>
            )}

            {/* Send Button */}
            <button
              type="submit"
              disabled={loading || !toAddress || !amount || !isValidAddress(toAddress) || parseFloat(amount) <= 0}
              className="glass-button w-full touch-target h-14 text-lg disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <div className="flex items-center justify-center">
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                  Sending...
                </div>
              ) : (
                "Send Transaction"
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
} 