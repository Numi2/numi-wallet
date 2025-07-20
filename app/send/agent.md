# Send Directory - Agent Documentation

## Overview
This directory contains the transaction sending interface for the Numi Wallet application.

## Files

### page.tsx
Comprehensive transaction sending interface with address validation, gas estimation, and transaction confirmation.

## Key Features

### Transaction Sending
- **Address Validation**: Real-time validation of recipient addresses
- **Amount Input**: Numeric input with step precision for ETH amounts
- **Gas Estimation**: Automatic gas limit and fee calculation
- **Balance Checking**: Ensures sufficient balance including gas fees
- **MAX Button**: Automatically fills maximum sendable amount

### User Experience
- **Real-time Feedback**: Address validation and gas estimation updates
- **Error Handling**: Comprehensive error messages and validation
- **Success Confirmation**: Transaction hash display after successful send
- **Loading States**: Visual feedback during transaction processing

### Security Features
- **Address Validation**: Uses ethers.js address validation
- **Balance Verification**: Prevents overspending
- **Gas Fee Calculation**: Includes gas fees in balance checks
- **Transaction Confirmation**: Clear transaction details before sending

## Technical Implementation

### Gas Estimation
- Real-time gas limit calculation using `estimateGas()`
- Current gas price fetching using `getGasPrice()`
- Total fee calculation and display
- Automatic updates when address or amount changes

### Transaction Processing
- Uses `sendTransaction()` from wallet utilities
- Connects wallet to provider before sending
- Handles transaction signing and broadcasting
- Automatic balance and transaction history refresh

### Validation
- Address format validation
- Amount validation (positive, sufficient balance)
- Gas estimation validation
- Network connectivity checks

## Dependencies
- React hooks (useState, useEffect, useRouter)
- WalletContext for wallet state and balance
- lib/wallet utilities for blockchain interaction
- ethers.js for address validation and gas estimation

## User Flow
1. User enters recipient address
2. Address is validated in real-time
3. User enters amount
4. Gas is estimated automatically
5. User reviews transaction details
6. User confirms and sends transaction
7. Success confirmation with transaction hash

## Error Handling
- Invalid address format
- Insufficient balance
- Network connectivity issues
- Gas estimation failures
- Transaction broadcasting errors 