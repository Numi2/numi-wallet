# Dashboard Directory - Agent Documentation

## Overview
This directory contains the main wallet dashboard interface for the Numi Wallet application.

## Files

### page.tsx
Main wallet interface with unlock functionality and wallet management features.

## Interface States

### Locked State
- Password unlock form
- Error handling for invalid passwords
- Loading states during unlock process
- Form validation and submission

### Unlocked State
- Wallet address display
- Balance information (placeholder for future implementation)
- Quick action buttons (Send, Receive, Swap)
- Lock wallet functionality

## Key Features

### Wallet Management
- Password-based wallet unlocking
- Secure wallet state management via WalletContext
- Automatic redirect to onboarding if no wallet exists
- Lock wallet functionality for security

### UI Components
- Responsive grid layout
- Card-based information display
- Action buttons for wallet operations
- Loading and error states

### Security
- Password validation and error handling
- Secure wallet state management
- Automatic session management
- Protected route access

## Dependencies
- React hooks (useState, useEffect, useRouter)
- WalletContext for state management
- lib/wallet utilities
- Next.js navigation and routing

## Future Enhancements
- Balance fetching from blockchain
- Transaction history
- Token management
- Advanced wallet features

## User Experience
- Clean, modern interface design
- Intuitive navigation and actions
- Clear error messaging
- Responsive design for all devices 