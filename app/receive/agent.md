# Receive Directory - Agent Documentation

## Overview
This directory contains the receive functionality for the Numi Wallet application, allowing users to share their wallet address for receiving ETH.

## Files

### page.tsx
Receive interface with QR code generation, address display, and sharing functionality.

## Key Features

### Address Sharing
- **QR Code Generation**: Automatic QR code generation for wallet address
- **Address Display**: Full wallet address with copy functionality
- **Copy to Clipboard**: One-click address copying
- **Native Sharing**: Uses Web Share API when available

### QR Code Implementation
- **External Service**: Uses QR Server API for QR code generation
- **Responsive Design**: QR code scales appropriately
- **Error Handling**: Graceful fallback if QR generation fails

### User Experience
- **Visual QR Code**: Easy scanning for mobile devices
- **Copy Confirmation**: Visual feedback when address is copied
- **Share Integration**: Native sharing on supported devices
- **Clear Instructions**: Step-by-step guidance for users

## Technical Implementation

### QR Code Generation
```javascript
const generateQRCode = (text: string) => {
  return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(text)}`;
};
```

### Clipboard Integration
- Uses `navigator.clipboard.writeText()` for copying
- Fallback handling for unsupported browsers
- Visual feedback with copied state

### Web Share API
- Conditional rendering based on `navigator.share` availability
- Structured sharing with title, text, and URL
- Graceful fallback to copy functionality

## Security Features

### Address Display
- **Full Address**: Complete wallet address display
- **No Private Data**: Only public address is shown
- **Secure Sharing**: No sensitive information exposed

### User Guidance
- **Security Tips**: Clear security warnings
- **Best Practices**: Instructions for safe address sharing
- **Network Information**: Clarification about ETH-only receiving

## Dependencies
- React hooks (useState, useEffect, useRouter)
- WalletContext for wallet address access
- lib/wallet utilities for address formatting
- Web APIs (Clipboard API, Share API)

## User Flow
1. User navigates to receive page
2. QR code is automatically generated
3. User can copy address to clipboard
4. User can share address via native sharing
5. User receives clear instructions and security tips

## Mobile Optimization
- **QR Code Scanning**: Optimized for mobile camera scanning
- **Touch Interactions**: Large touch targets for buttons
- **Responsive Layout**: Adapts to different screen sizes
- **Native Sharing**: Leverages device sharing capabilities

## Future Enhancements
- **Custom QR Codes**: Stylized QR codes with branding
- **Address Book**: Save frequently used addresses
- **Multi-currency**: Support for different cryptocurrencies
- **Deep Linking**: Direct address sharing via links 