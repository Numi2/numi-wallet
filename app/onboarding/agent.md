# Onboarding Directory - Agent Documentation

## Overview
This directory contains the wallet onboarding flow for new users in the Numi Wallet application.

## Files

### page.tsx
Multi-step wallet creation interface with secure mnemonic generation and storage.

## Step Flow

### Step 1: Create Wallet
- Displays welcome message and wallet creation button
- Generates new mnemonic using `generateMnemonic()`
- Transitions to confirmation step

### Step 2: Confirm Mnemonic
- Displays 12-word recovery phrase in secure format
- Warns user to write down the phrase
- Confirmation button to proceed to password step

### Step 3: Set Password
- Password input with validation
- Confirm password field
- Password requirements: minimum 8 characters
- Encrypts and stores wallet using `encryptAndStore()`
- Redirects to dashboard upon successful creation

## Security Features
- Mnemonic generation using ethers.js
- AES encryption for storage
- Password validation and confirmation
- Secure display of recovery phrase

## UI Components
- Step-based navigation
- Form validation with error messages
- Responsive design with Tailwind CSS
- Loading states and transitions

## Dependencies
- React hooks (useState, useRouter)
- lib/wallet utilities
- Next.js navigation
- Tailwind CSS for styling

## User Experience
- Clear step-by-step guidance
- Important security warnings
- Intuitive form validation
- Smooth transitions between steps 