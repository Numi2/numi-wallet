import { ethers, HDNodeWallet, TransactionResponse } from "ethers";
import CryptoJS from "crypto-js";

const WALLET_STORAGE_KEY = "numi_wallet_encrypted";

/**
 * Generate a new mnemonic phrase
 * @returns A 12-word mnemonic phrase
 */
export function generateMnemonic(): string {
  return ethers.Wallet.createRandom().mnemonic?.phrase || "";
}

/**
 * Encrypt and store the mnemonic phrase in localStorage
 * @param mnemonic The mnemonic phrase to encrypt
 * @param password The password to encrypt with
 */
export function encryptAndStore(mnemonic: string, password: string): void {
  try {
    // Encrypt the mnemonic using AES
    const encrypted = CryptoJS.AES.encrypt(mnemonic, password).toString();
    
    // Store the encrypted mnemonic in localStorage
    if (typeof window !== "undefined") {
      localStorage.setItem(WALLET_STORAGE_KEY, encrypted);
    }
  } catch (error) {
    console.error("Error encrypting and storing wallet:", error);
    throw new Error("Failed to encrypt and store wallet");
  }
}

/**
 * Load and decrypt the wallet from localStorage
 * @param password The password to decrypt with
 * @returns The ethers HDNodeWallet instance
 */
export function loadWallet(password: string): HDNodeWallet {
  try {
    if (typeof window === "undefined") {
      throw new Error("Cannot access localStorage on server side");
    }

    const encryptedMnemonic = localStorage.getItem(WALLET_STORAGE_KEY);
    if (!encryptedMnemonic) {
      throw new Error("No wallet found");
    }

    // Decrypt the mnemonic
    const decrypted = CryptoJS.AES.decrypt(encryptedMnemonic, password);
    const mnemonic = decrypted.toString(CryptoJS.enc.Utf8);

    if (!mnemonic) {
      throw new Error("Invalid password");
    }

    // Create wallet from mnemonic
    return ethers.Wallet.fromPhrase(mnemonic);
  } catch (error) {
    console.error("Error loading wallet:", error);
    throw new Error("Failed to load wallet. Please check your password.");
  }
}

/**
 * Load wallet directly from recovery phrase
 * @param recoveryPhrase The 12-word recovery phrase
 * @returns The ethers HDNodeWallet instance
 */
export function loadWalletFromPhrase(recoveryPhrase: string): HDNodeWallet {
  try {
    // Validate the recovery phrase
    const words = recoveryPhrase.trim().split(' ');
    if (words.length !== 12) {
      throw new Error("Recovery phrase must be exactly 12 words");
    }

    // Create wallet from recovery phrase
    return ethers.Wallet.fromPhrase(recoveryPhrase.trim());
  } catch (error) {
    console.error("Error loading wallet from phrase:", error);
    throw new Error("Invalid recovery phrase. Please check your 12 words.");
  }
}

/**
 * Check if a wallet exists in localStorage
 * @returns True if a wallet exists, false otherwise
 */
export function hasWallet(): boolean {
  if (typeof window === "undefined") {
    return false;
  }
  return localStorage.getItem(WALLET_STORAGE_KEY) !== null;
}

/**
 * Get the JSON-RPC provider
 * @returns The ethers JsonRpcProvider instance
 */
export function getProvider(): ethers.JsonRpcProvider {
  const rpcUrl = process.env.NEXT_PUBLIC_RPC_URL;
  if (!rpcUrl) {
    throw new Error("NEXT_PUBLIC_RPC_URL environment variable is not set");
  }
  return new ethers.JsonRpcProvider(rpcUrl);
}

/**
 * Clear the stored wallet from localStorage
 */
export function clearWallet(): void {
  if (typeof window !== "undefined") {
    localStorage.removeItem(WALLET_STORAGE_KEY);
  }
}

// ===== NEW FUNCTIONS FOR BALANCE & TRANSACTIONS =====

/**
 * Get wallet balance in ETH
 * @param address The wallet address
 * @returns Balance in ETH as a string
 */
export async function getBalance(address: string): Promise<string> {
  try {
    const provider = getProvider();
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
  } catch (error) {
    console.error("Error fetching balance:", error);
    throw new Error("Failed to fetch balance");
  }
}

/**
 * Get transaction count (nonce) for an address
 * @param address The wallet address
 * @returns The current nonce
 */
export async function getTransactionCount(address: string): Promise<number> {
  try {
    const provider = getProvider();
    return await provider.getTransactionCount(address);
  } catch (error) {
    console.error("Error fetching transaction count:", error);
    throw new Error("Failed to fetch transaction count");
  }
}

/**
 * Estimate gas for a transaction
 * @param fromAddress The sender address
 * @param toAddress The recipient address
 * @param amount The amount to send in ETH
 * @returns Estimated gas limit
 */
export async function estimateGas(
  fromAddress: string,
  toAddress: string,
  amount: string
): Promise<bigint> {
  try {
    const provider = getProvider();
    const amountWei = ethers.parseEther(amount);
    
    const transaction = {
      from: fromAddress,
      to: toAddress,
      value: amountWei,
    };
    
    return await provider.estimateGas(transaction);
  } catch (error) {
    console.error("Error estimating gas:", error);
    throw new Error("Failed to estimate gas");
  }
}

/**
 * Get current gas price
 * @returns Current gas price in wei
 */
export async function getGasPrice(): Promise<bigint> {
  try {
    const provider = getProvider();
    return await provider.getFeeData().then(feeData => feeData.gasPrice || 0n);
  } catch (error) {
    console.error("Error fetching gas price:", error);
    throw new Error("Failed to fetch gas price");
  }
}

/**
 * Send a transaction
 * @param wallet The wallet instance
 * @param toAddress The recipient address
 * @param amount The amount to send in ETH
 * @param gasLimit Optional gas limit (will estimate if not provided)
 * @returns Transaction hash
 */
export async function sendTransaction(
  wallet: HDNodeWallet,
  toAddress: string,
  amount: string,
  gasLimit?: bigint
): Promise<string> {
  try {
    const provider = getProvider();
    const connectedWallet = wallet.connect(provider);
    
    const amountWei = ethers.parseEther(amount);
    const estimatedGas = gasLimit || await estimateGas(wallet.address, toAddress, amount);
    const gasPrice = await getGasPrice();
    
    const transaction = {
      to: toAddress,
      value: amountWei,
      gasLimit: estimatedGas,
      gasPrice: gasPrice,
    };
    
    const tx = await connectedWallet.sendTransaction(transaction);
    return tx.hash;
  } catch (error) {
    console.error("Error sending transaction:", error);
    throw new Error("Failed to send transaction");
  }
}

/**
 * Get transaction history for an address
 * @param address The wallet address
 * @param limit Number of transactions to fetch (default: 10)
 * @returns Array of transaction objects
 */
export async function getTransactionHistory(
  address: string,
  limit: number = 10
): Promise<any[]> {
  try {
    const provider = getProvider();
    const blockNumber = await provider.getBlockNumber();
    
    const transactions = [];
    const blocksToCheck = Math.min(limit * 2, 1000); // Check more blocks to find transactions
    
    for (let i = 0; i < blocksToCheck && transactions.length < limit; i++) {
      const block = await provider.getBlock(blockNumber - i, true);
      if (!block) continue;
      
      for (const tx of block.transactions) {
        // Only process if tx is an object (not a string/hash)
        if (typeof tx === 'object' && tx !== null && 'from' in tx && 'to' in tx) {
          const txObj = tx as TransactionResponse;
          if (
            (txObj.from?.toLowerCase() === address.toLowerCase()) ||
            (txObj.to?.toLowerCase() === address.toLowerCase())
          ) {
            transactions.push({
              hash: txObj.hash,
              from: txObj.from,
              to: txObj.to,
              value: ethers.formatEther(txObj.value || 0),
              gasPrice: txObj.gasPrice?.toString(),
              gasLimit: txObj.gasLimit?.toString(),
              blockNumber: txObj.blockNumber,
              timestamp: block.timestamp,
              type: txObj.from?.toLowerCase() === address.toLowerCase() ? 'sent' : 'received'
            });
            if (transactions.length >= limit) break;
          }
        }
      }
    }
    
    return transactions.sort((a, b) => b.timestamp - a.timestamp);
  } catch (error) {
    console.error("Error fetching transaction history:", error);
    throw new Error("Failed to fetch transaction history");
  }
}

/**
 * Get transaction details by hash
 * @param txHash The transaction hash
 * @returns Transaction details
 */
export async function getTransactionDetails(txHash: string): Promise<any> {
  try {
    const provider = getProvider();
    const tx = await provider.getTransaction(txHash);
    const receipt = await provider.getTransactionReceipt(txHash);
    
    if (!tx) {
      throw new Error("Transaction not found");
    }
    
    return {
      hash: tx.hash,
      from: tx.from,
      to: tx.to,
      value: ethers.formatEther(tx.value || 0),
      gasPrice: tx.gasPrice?.toString(),
      gasLimit: tx.gasLimit?.toString(),
      gasUsed: receipt?.gasUsed?.toString(),
      blockNumber: tx.blockNumber,
      status: receipt?.status,
      ...(receipt && 'effectiveGasPrice' in receipt ? { effectiveGasPrice: (receipt as any).effectiveGasPrice?.toString() } : {}),
    };
  } catch (error) {
    console.error("Error fetching transaction details:", error);
    throw new Error("Failed to fetch transaction details");
  }
}

/**
 * Validate Ethereum address
 * @param address The address to validate
 * @returns True if valid, false otherwise
 */
export function isValidAddress(address: string): boolean {
  try {
    return ethers.isAddress(address);
  } catch {
    return false;
  }
}

/**
 * Format address for display (shortened version)
 * @param address The full address
 * @returns Shortened address (e.g., 0x1234...5678)
 */
export function formatAddress(address: string): string {
  if (!address) return "";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
} 