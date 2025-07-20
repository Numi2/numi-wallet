# Lib Directory - Agent Documentation

## Overview
This directory contains utility functions for wallet management in the Numi Wallet application.

## Files

### wallet.ts
Core wallet management utilities using ethers.js and crypto-js for encryption.

**Key Functions:**
- `generateMnemonic()`: Creates a new 12-word mnemonic phrase
- `encryptAndStore(mnemonic, password)`: Encrypts and stores mnemonic in localStorage
- `loadWallet(password)`: Decrypts and loads wallet from localStorage
- `hasWallet()`: Checks if a wallet exists in localStorage
- `getProvider()`: Returns ethers JsonRpcProvider using NEXT_PUBLIC_RPC_URL
- `clearWallet()`: Removes wallet from localStorage

**Dependencies:**
- ethers.js for wallet operations
- crypto-js for AES encryption
- localStorage for persistent storage

**Security Notes:**
- Uses AES encryption for mnemonic storage
- Server-side safe with window checks
- Environment variable required for RPC provider

## Usage
Import functions directly from `@/lib/wallet` in components and contexts. 