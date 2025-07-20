# App Directory - Agent Documentation

## Overview
This directory contains the Next.js App Router pages and layout for the Numi Wallet application.

## Structure

### layout.tsx (Root Layout)
- Wraps the entire application with WalletProvider
- Imports global CSS and fonts
- Sets up metadata for the application

### page.tsx (Home Page)
- Entry point with redirect logic
- Checks if wallet exists using `hasWallet()`
- Redirects to `/onboarding` if no wallet
- Redirects to `/dashboard` if wallet exists
- Shows loading state during redirect

### /onboarding/page.tsx
Multi-step wallet creation flow:
1. **Create Step**: Generate new wallet button
2. **Confirm Step**: Display mnemonic for backup
3. **Password Step**: Set encryption password

**Features:**
- Mnemonic generation and display
- Password validation (8+ characters, confirmation)
- Secure wallet storage
- Step-by-step UI flow

### /dashboard/page.tsx
Main wallet interface with two states:
1. **Locked State**: Password unlock form
2. **Unlocked State**: Wallet dashboard with address and actions

**Features:**
- Wallet unlock functionality
- Display wallet address
- Quick action buttons (Send, Receive, Swap)
- Lock wallet functionality
- Balance display (placeholder)

## Routing Logic
- `/` → Redirects based on wallet existence
- `/onboarding` → Wallet creation flow
- `/dashboard` → Main wallet interface

## Dependencies
- Next.js App Router
- React hooks and context
- lib/wallet utilities
- WalletContext for state management

## Security
- Password-protected wallet access
- Encrypted storage
- Automatic redirects for unauthorized access 