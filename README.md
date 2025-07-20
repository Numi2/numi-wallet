# Numi Wallet

A secure cryptocurrency wallet built with Next.js, TypeScript, and ethers.js.

## Features

- 🔐 Secure wallet creation with mnemonic backup
- 🔒 Password-protected wallet access
- 💰 Multi-chain wallet support
- 🎨 Modern UI with Tailwind CSS
- 📱 Responsive design
- 🔄 Real-time balance updates (coming soon)

## Tech Stack

- **Framework**: Next.js 15 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Blockchain**: ethers.js
- **Encryption**: crypto-js
- **UI Components**: shadcn/ui (ready for integration)

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd numi-wallet
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
Create a `.env.local` file in the root directory:
```env
NEXT_PUBLIC_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
```

4. Run the development server:
```bash
npm run dev
```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
numi-wallet/
├── app/                    # Next.js App Router pages
│   ├── dashboard/         # Main wallet interface
│   ├── onboarding/        # Wallet creation flow
│   ├── layout.tsx         # Root layout with providers
│   └── page.tsx           # Entry point with redirects
├── context/               # React Context providers
│   └── WalletContext.tsx  # Wallet state management
├── lib/                   # Utility functions
│   └── wallet.ts          # Wallet management utilities
├── components/            # Reusable UI components
│   └── ui/               # shadcn/ui components (ready)
└── public/               # Static assets
```

## Wallet Security

- **Mnemonic Generation**: Uses ethers.js for secure mnemonic generation
- **Encryption**: AES encryption for mnemonic storage
- **Password Protection**: User-defined password for wallet access
- **Local Storage**: Encrypted wallet data stored locally
- **No Server Storage**: Private keys never leave the client

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run lint` - Run ESLint

### Adding New Features

1. **Wallet Operations**: Extend `lib/wallet.ts` with new functions
2. **UI Components**: Add components to `components/ui/` using shadcn/ui
3. **Pages**: Create new pages in the `app/` directory
4. **State Management**: Extend `WalletContext.tsx` for new state

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NEXT_PUBLIC_RPC_URL` | JSON-RPC endpoint URL | Yes |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Security

This is a development project. For production use, ensure:
- Proper security audits
- Regular dependency updates
- Secure deployment practices
- User education on wallet security
