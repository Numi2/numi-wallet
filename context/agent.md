# Context Directory - Agent Documentation

## Overview
This directory contains React Context providers for global state management in the Numi Wallet application.

## Files

### WalletContext.tsx
React Context for wallet state management throughout the application.

**Key Features:**
- Global wallet state management
- Loading and error states
- Wallet unlock functionality
- Server-side rendering safe

**Context Interface:**
```typescript
{
  wallet: Wallet | null;
  loading: boolean;
  error?: string;
  unlock(password: string): Promise<void>;
  clearError(): void;
}
```

**Provider Features:**
- Automatically checks for existing wallet on mount
- Handles wallet loading with error management
- Provides loading states for UI feedback
- Error clearing functionality

**Usage:**
- Wrap app in `WalletProvider` in root layout
- Use `useWallet()` hook in components
- Access wallet state, loading, errors, and unlock function

**Dependencies:**
- React Context API
- ethers.js Wallet type
- lib/wallet utilities

## Integration
The WalletProvider is integrated in the root layout (`app/layout.tsx`) to provide wallet context throughout the application. 