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
 * Create a new wallet and store it encrypted
 * @param password The password to encrypt with
 * @returns The ethers HDNodeWallet instance
 */
export async function createWallet(password: string = "numicoin"): Promise<HDNodeWallet> {
  try {
    const mnemonic = generateMnemonic();
    const wallet = ethers.Wallet.fromPhrase(mnemonic);
    
    // Encrypt and store the wallet
    encryptAndStore(mnemonic, password);
    
    return wallet;
  } catch (error) {
    console.error("Error creating wallet:", error);
    throw new Error("Failed to create wallet");
  }
}

/**
 * Import wallet from recovery phrase
 * @param recoveryPhrase The 12-word recovery phrase
 * @param password The password to encrypt with
 * @returns The ethers HDNodeWallet instance
 */
export async function importWallet(recoveryPhrase: string, password: string = "numicoin"): Promise<HDNodeWallet> {
  try {
    const wallet = loadWalletFromPhrase(recoveryPhrase);
    
    // Encrypt and store the wallet
    encryptAndStore(recoveryPhrase, password);
    
    return wallet;
  } catch (error) {
    console.error("Error importing wallet:", error);
    throw new Error("Failed to import wallet");
  }
}

/**
 * Get the current wallet from storage
 * @returns The ethers HDNodeWallet instance or null
 */
export function getWallet(): HDNodeWallet | null {
  try {
    if (typeof window === "undefined") {
      return null;
    }

    const encryptedMnemonic = localStorage.getItem(WALLET_STORAGE_KEY);
    if (!encryptedMnemonic) {
      return null;
    }

    // Try to decrypt with default password
    try {
      const decrypted = CryptoJS.AES.decrypt(encryptedMnemonic, "numicoin");
      const mnemonic = decrypted.toString(CryptoJS.enc.Utf8);
      
      if (mnemonic) {
        return ethers.Wallet.fromPhrase(mnemonic);
      }
    } catch (error) {
      // Wallet exists but password is different
      return null;
    }

    return null;
  } catch (error) {
    console.error("Error getting wallet:", error);
    return null;
  }
}

/**
 * Lock the wallet (remove from memory)
 */
export function lockWallet(): void {
  // In a real implementation, you'd clear the wallet from memory
  // For now, we just clear any session data
  if (typeof window !== "undefined") {
    // Clear any session-related data
    sessionStorage.clear();
  }
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
  const rpcUrl = process.env.NEXT_PUBLIC_RPC_URL || "https://mainnet.infura.io/v3/YOUR_PROJECT_ID";
  return new ethers.JsonRpcProvider(rpcUrl);
}

/**
 * Clear the wallet from localStorage
 */
export function clearWallet(): void {
  if (typeof window !== "undefined") {
    localStorage.removeItem(WALLET_STORAGE_KEY);
    sessionStorage.clear();
  }
}

/**
 * Get the balance of an address
 * @param address The address to get the balance for
 * @returns The balance as a string
 */
export async function getBalance(address: string): Promise<string> {
  try {
    const provider = getProvider();
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
  } catch (error) {
    console.error("Error getting balance:", error);
    return "0";
  }
}

/**
 * Get the transaction count (nonce) for an address
 * @param address The address to get the nonce for
 * @returns The nonce as a number
 */
export async function getTransactionCount(address: string): Promise<number> {
  try {
    const provider = getProvider();
    return await provider.getTransactionCount(address);
  } catch (error) {
    console.error("Error getting transaction count:", error);
    return 0;
  }
}

/**
 * Estimate gas for a transaction
 * @param fromAddress The sender address
 * @param toAddress The recipient address
 * @param amount The amount to send
 * @returns The estimated gas as a bigint
 */
export async function estimateGas(
  fromAddress: string,
  toAddress: string,
  amount: string
): Promise<bigint> {
  try {
    const provider = getProvider();
    const gasEstimate = await provider.estimateGas({
      from: fromAddress,
      to: toAddress,
      value: ethers.parseEther(amount),
    });
    return gasEstimate;
  } catch (error) {
    console.error("Error estimating gas:", error);
    return BigInt(21000); // Default gas limit
  }
}

/**
 * Get the current gas price
 * @returns The gas price as a bigint
 */
export async function getGasPrice(): Promise<bigint> {
  try {
    const provider = getProvider();
    return await provider.getFeeData().then(feeData => feeData.gasPrice || BigInt(0));
  } catch (error) {
    console.error("Error getting gas price:", error);
    return BigInt(20000000000); // 20 gwei default
  }
}

/**
 * Send a transaction
 * @param wallet The wallet to send from
 * @param toAddress The recipient address
 * @param amount The amount to send
 * @param gasLimit Optional gas limit
 * @returns The transaction hash
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
    
    const tx = await connectedWallet.sendTransaction({
      to: toAddress,
      value: ethers.parseEther(amount),
      gasLimit: gasLimit || BigInt(21000),
    });
    
    return tx.hash;
  } catch (error) {
    console.error("Error sending transaction:", error);
    throw new Error("Failed to send transaction");
  }
}

/**
 * Add mining reward to local storage (for browser mining)
 * @param walletAddress The wallet address
 * @param amount The amount to add
 */
export function addMiningReward(walletAddress: string, amount: string): void {
  if (typeof window === "undefined") return;
  
  try {
    const key = `mining_rewards_${walletAddress}`;
    const currentRewards = localStorage.getItem(key) || "0";
    const newRewards = (parseFloat(currentRewards) + parseFloat(amount)).toString();
    localStorage.setItem(key, newRewards);
  } catch (error) {
    console.error("Error adding mining reward:", error);
  }
}

/**
 * Get mining rewards from local storage
 * @param walletAddress The wallet address
 * @returns The mining rewards as a string
 */
export function getMiningRewards(walletAddress: string): string {
  if (typeof window === "undefined") return "0";
  
  try {
    const key = `mining_rewards_${walletAddress}`;
    return localStorage.getItem(key) || "0";
  } catch (error) {
    console.error("Error getting mining rewards:", error);
    return "0";
  }
}

/**
 * Get transaction history for an address
 * @param address The address to get transactions for
 * @param limit The maximum number of transactions to return
 * @returns Array of transactions
 */
export async function getTransactionHistory(
  address: string,
  limit: number = 10
): Promise<any[]> {
  try {
    const provider = getProvider();
    const blockNumber = await provider.getBlockNumber();
    
    const transactions: any[] = [];
    
    // Get recent blocks and look for transactions
    for (let i = 0; i < Math.min(limit * 10, 100); i++) {
      const blockNumberToCheck = blockNumber - i;
      if (blockNumberToCheck < 0) break;
      
      try {
        const block = await provider.getBlock(blockNumberToCheck, true);
        if (block && block.transactions) {
          for (const tx of block.transactions) {
            if (tx.from === address || tx.to === address) {
              transactions.push({
                hash: tx.hash,
                from: tx.from,
                to: tx.to,
                value: ethers.formatEther(tx.value),
                blockNumber: blockNumberToCheck,
                timestamp: block.timestamp,
                type: tx.from === address ? 'sent' : 'received'
              });
              
              if (transactions.length >= limit) {
                return transactions;
              }
            }
          }
        }
      } catch (error) {
        // Skip blocks that can't be fetched
        continue;
      }
    }
    
    return transactions;
  } catch (error) {
    console.error("Error getting transaction history:", error);
    return [];
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
      value: ethers.formatEther(tx.value),
      gasPrice: tx.gasPrice?.toString(),
      gasLimit: tx.gasLimit?.toString(),
      blockNumber: tx.blockNumber,
      confirmations: tx.confirmations,
      status: receipt?.status === 1 ? 'success' : 'failed'
    };
  } catch (error) {
    console.error("Error getting transaction details:", error);
    throw new Error("Failed to get transaction details");
  }
}

/**
 * Validate if an address is a valid Ethereum address
 * @param address The address to validate
 * @returns True if valid, false otherwise
 */
export function isValidAddress(address: string): boolean {
  try {
    return ethers.isAddress(address);
  } catch (error) {
    return false;
  }
}

/**
 * Format an address for display (shortened)
 * @param address The address to format
 * @returns The formatted address
 */
export function formatAddress(address: string): string {
  if (!isValidAddress(address)) {
    return "Invalid Address";
  }
  
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
} 