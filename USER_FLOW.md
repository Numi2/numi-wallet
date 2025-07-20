# Numi Wallet User Flow

## For New Users (No Existing Wallet)

1. **Visit the site** → Redirected to `/onboarding`
2. **Choose setup option**:
   - Create New Wallet
   - Import Existing Wallet (if they have a recovery phrase)
3. **Create New Wallet flow**:
   - Generate 12-word recovery phrase
   - User writes down the phrase
   - Set password
   - Wallet created and encrypted
4. **Import Wallet flow**:
   - Enter 12-word recovery phrase
   - Set password
   - Wallet imported and encrypted
5. **Redirected to dashboard** → Wallet is unlocked and ready to use

## For Existing Users (Has Wallet)

1. **Visit the site** → Redirected to `/login`
2. **Login page**:
   - Enter 12-word recovery phrase to unlock wallet
   - Option to create new wallet (clears existing one)
3. **Successful login** → Redirected to `/dashboard`
4. **Dashboard** → Wallet unlocked and ready to use

## Dashboard Features

- **Locked State**: If wallet is locked, shows login form
- **Unlocked State**: Shows wallet address, balance, and quick actions
- **Quick Actions**:
  - Send ETH
  - Receive ETH
  - Swap (placeholder)
- **Transaction History**: Shows recent transactions
- **Lock Wallet**: Logs out and returns to login page

## Security Features

- **Recovery Phrase Authentication**: Users must enter their 12-word recovery phrase to access their wallet
- **Session Management**: Auto-lock after inactivity
- **Recovery Phrase**: 12-word mnemonic for wallet recovery and authentication
- **Local Storage**: Encrypted wallet data stored locally

## Navigation Flow

```
/ (root)
├── hasWallet() = false → /onboarding
└── hasWallet() = true → /login

/onboarding
├── Create New Wallet → /dashboard
└── Import Wallet → /dashboard

/login
├── Valid Password → /dashboard
└── Create New Wallet → /onboarding

/dashboard
├── Wallet Locked → Show login form
└── Wallet Unlocked → Show dashboard

/send → Requires unlocked wallet
/receive → Requires unlocked wallet
```

## Glass Morphism Design

The app features a beautiful glass morphism design with:
- Backdrop blur effects
- Semi-transparent backgrounds
- Gradient animations
- Liquid background effects
- Smooth transitions and hover states 