# Numi State Of The Art Apple Plan

Last updated: April 5, 2026

See also:

- [Numi Future Of Crypto Roadmap](NUMI_FUTURE_OF_CRYPTO_ROADMAP.md)
- [Numi Tachyon Execution Guide](NUMI_TACHYON_EXECUTION_GUIDE.md)
- [Numi Architecture And Roadmap](NUMI_ARCHITECTURE_AND_ROADMAP.md)
- [Numi Apple Ecosystem Design Roadmap](NUMI_APPLE_ECOSYSTEM_DESIGN_ROADMAP.md)

## Purpose

This document is the current execution brief for Numi Wallet as an Apple-only sovereign wallet product. It records:

- the platform guidance that should shape product and implementation decisions
- the architecture choices already reflected in the codebase
- the code changes made in the current development pass
- the recommended roadmap from prototype shell to state-of-the-art shipping product

This is not a generic backlog. It is the intended path for a privacy-first, post-quantum wallet that uses Apple hardware and APIs as part of its security model.

## Apple Platform Anchors

These Apple references should actively shape Numi, not sit as passive links in a document:

- Human Interface Guidelines: Privacy
  - <https://developer.apple.com/design/human-interface-guidelines/privacy>
  - Guidance to request only the data actually needed, process on-device where possible, store sensitive information in Keychain, avoid plaintext secure content, and prefer system privacy and security features.
- Human Interface Guidelines and Liquid Glass
  - <https://developer.apple.com/design/human-interface-guidelines>
  - <https://developer.apple.com/documentation/technologyoverviews/liquid-glass>
  - Liquid Glass should clarify hierarchy and interaction state. It is structural, not decorative.
- Local Authentication
  - <https://developer.apple.com/documentation/localauthentication/>
  - Numi should keep device-owner authentication explicit and system-native. The installed iOS 26.4 public SDK does not expose `LocalAuthenticationView`, so iPhone auth should stay on `LAContext`, Keychain access control, and system sheets.
- App Attest
  - <https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server>
  - Remote services should verify that the client is a real Apple app instance and reject replay, abuse, and downgrade paths.
- Secure Enclave
  - <https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave>
  - Hardware isolation is not optional decoration. It is part of Numi’s trust boundary.
- Storing CryptoKit keys in the Keychain
  - <https://developer.apple.com/documentation/CryptoKit/storing-cryptokit-keys-in-the-keychain>
  - Persisted key references should be device-bound and keychain-centered.
- Quantum-secure workflows
  - <https://developer.apple.com/documentation/cryptokit/enhancing-your-app-s-privacy-and-security-with-quantum-secure-workflows>
  - <https://developer.apple.com/videos/play/wwdc2025/314/>
  - Apple’s guidance is to adopt quantum-secure cryptography now, especially for data that must remain secure in the future, and to use hybrid approaches where a full switch is not yet appropriate.
- Quantum-secure TLS
  - <https://developer.apple.com/documentation/network/preparing-your-network-for-quantum-secure-encryption-in-tls>
  - Numi should keep all remote traffic on Apple system TLS and avoid a custom transport stack.
- Nearby Interaction
  - <https://developer.apple.com/nearby-interaction/>
  - <https://developer.apple.com/documentation/nearbyinteraction/ninearbypeerconfiguration>
  - <https://developer.apple.com/documentation/nearbyinteraction/finding-devices-with-precision>
  - Nearby physical trust should graduate from a toggle to a spatially informed peer signal.

## Product Conclusions From Apple Guidance

Apple’s guidance implies several product decisions that should be treated as settled:

1. Numi should remain Apple-only.
2. Numi should remain quiet by default.
3. Sensitive material should prefer full-screen, system-native, explicit flows over inline utility widgets.
4. Privileged moments should use local authentication and device-owner confirmation as a visible part of the product.
5. Sensitive state should be short-lived in memory and aggressively redacted on lifecycle or capture events.
6. The app should process and decide on-device wherever possible.
7. Quantum-safe posture is not a marketing note. It should shape the long-lived cryptographic architecture now.

## Architecture Now

The codebase already contains several strong foundations:

- Secure Enclave-backed `MLDSA87` authority and peer identity management.
- Device-only keychain storage for vault wrapping material, spend authorization, descriptor secrets, ratchet secrets, and App Attest key IDs.
- Authority/day/vault wallet split with policy-gated vault visibility.
- App Attest-aware networking clients.
- Pairing invitation and attested session transcript model.
- PIR and shielded-state plumbing behind capability gates.
- Dynamic-fee and proving prototypes.
- Privacy lifecycle handling for capture, screenshots, backgrounding, and protected-data loss.

## Locked Cryptography Decisions

These decisions should now be treated as architectural defaults, not experiments:

1. Long-lived authority and peer identity stay on `SecureEnclave.MLDSA87`.
2. Fee-market authorization hotkeys use `MLDSA87`.
3. Descriptor delivery encryption uses `HPKE.XWingMLKEM768X25519_SHA256_AES_GCM_256`.
4. Tag-ratchet relationship bootstrap uses `XWingMLKEM768X25519` encapsulation, not `Curve25519` Diffie-Hellman.
5. Remote networking stays on Apple system TLS plus App Attest. Numi does not ship a custom TLS stack.
6. Numi does not maintain simulator or legacy-state crypto fallbacks in the authority architecture.

These are not superficial features. They are the beginnings of the correct architecture.

## Work Completed In This Pass

### 1. Immersive privileged surfaces

The iPhone shell now drives full-screen privileged surfaces rather than keeping every important action inline:

- authority ceremony
- vault chamber
- transit composer
- recovery studio
- Apple device graph view

Files:

- `Numi Wallet/UI/WalletDashboardView.swift`
- `Numi Wallet/UI/NumiImmersiveSurfaces.swift`

### 2. Typed wallet event architecture

The app now has a typed wallet event model instead of relying only on loose status strings.

This adds:

- `WalletExperienceEventKind`
- `WalletExperienceEvent`
- feedback semantics for success, warning, error, and selection
- recent event history for the UI

Why this matters:

- trust-state changes are now first-class product events
- haptics can be attached to meaningful state changes rather than arbitrary taps
- operator logs can show semantic history rather than just one opaque string

File:

- `Numi Wallet/Models/WalletExperienceModels.swift`

### 3. Recovery workspace inspection

The recovery workspace now has a typed inspection layer that parses staged text into:

- empty workspace
- single peer share
- quorum bundle
- invalid payload

Why this matters:

- the UI can explain what is staged before the user acts
- recovery actions can be enabled based on payload truth rather than text presence alone
- this is a direct step away from raw plaintext handling toward a bounded recovery product

Files:

- `Numi Wallet/Models/WalletExperienceModels.swift`
- `Numi Wallet/UI/WalletDashboardView.swift`
- `Numi Wallet/UI/NumiImmersiveSurfaces.swift`

### 4. Haptic routing for real wallet events

The shell now triggers feedback from typed wallet events instead of from generic UI changes alone. This better matches the design doctrine that haptics should confirm trust-state changes.

### 5. Real peer-trust sessions and signed recovery transfer envelopes

The old mutable peer toggle is gone from product flows. The authority lane now works with a short-lived peer-trust session model that carries:

- peer role
- peer device identity
- attested transcript fingerprint
- trust level
- expiry window

Recovery staging also moved forward. The workspace can now carry signed, time-bounded recovery transfer envelopes for:

- authority recovery bundles
- peer-share handoff

Why this matters:

- privileged flows now reason about explicit trust-session freshness instead of a debug boolean
- recovery payloads are typed, signed, and role-bounded before device-to-device transfer fully replaces the workspace
- the product direction is now aligned with authenticated local transfer rather than generic editable secret text

Files:

- `Numi Wallet/Models/PeerTrustModels.swift`
- `Numi Wallet/Pairing/PeerTrustCoordinator.swift`
- `Numi Wallet/Models/RecoveryTransferModels.swift`
- `Numi Wallet/Core/RecoveryTransferCoordinator.swift`
- `Numi Wallet/App/WalletAppModel.swift`
- `Numi Wallet/UI/WalletDashboardView.swift`

### 6. Apple security posture telemetry

Numi now inspects and reports real Apple trust posture instead of implying readiness through design alone.

The shell now measures:

- post-quantum hardware-root status
- owner authentication posture
- App Attest availability
- Nearby Interaction precision capability
- local state hardening
- privacy-boundary state

Why this matters:

- the dashboard now differentiates aesthetic trust from actual platform trust
- the authority ceremony can explain what the current device is genuinely capable of defending
- future policy decisions can be grounded in typed capability state rather than UI assumptions

Files:

- `Numi Wallet/Models/AppleSecurityPostureModels.swift`
- `Numi Wallet/Security/AppleSecurityPostureClient.swift`
- `Numi Wallet/App/WalletAppModel.swift`
- `Numi Wallet/UI/WalletDashboardView.swift`
- `Numi Wallet/UI/NumiImmersiveSurfaces.swift`

### 7. Role-specific roots and sealed trust ledger

The app now enters through role-specific root views instead of routing every device through the same top-level shell.

This adds:

- `NumiAuthorityPhoneRootView`
- `NumiRecoveryPeerRootView`
- `NumiMacPeerConsoleView`

It also adds a sealed local trust ledger that records:

- durable peer records
- session establish and seal events
- signed recovery-transfer preparation
- signed recovery-transfer consumption

Why this matters:

- the authority iPhone, recovery iPad, and proof Mac now have an explicit architectural split at app entry
- peer administration becomes inspectable state rather than only ephemeral UI
- this is the right substrate for the future Mac diagnostics lane and authenticated local transfer

Files:

- `Numi Wallet/UI/NumiRoleRootViews.swift`
- `Numi Wallet/Models/TrustLedgerModels.swift`
- `Numi Wallet/Core/TrustLedgerStore.swift`
- `Numi Wallet/App/WalletAppModel.swift`
- `Numi Wallet/UI/WalletDashboardView.swift`

### 8. Explicit Apple-native approval surfaces for privileged actions

Privileged wallet actions now move through a dedicated full-screen approval surface before the system prompt appears.

This now covers:

- vault chamber entry
- day and vault settlement approval
- recovery pair generation
- authority re-enrollment
- peer-share import and export
- local unwrap destruction

Why this matters:

- the user now sees the trust boundary before Local Authentication appears
- the resulting `LAContext` is reused by the real keychain and vault operation, avoiding a second surprise prompt
- recovery import, authority recovery, and panic custody paths now require explicit local approval instead of relying only on downstream storage policy

Important Apple SDK note:

- Apple documentation references `LocalAuthenticationView`, but the installed iOS 26.4 public SDK used for this pass does not expose that symbol in the public Swift module.
- Numi therefore treats `LAContext` plus Keychain access control as the canonical iPhone authentication architecture, with SwiftUI only framing the trust moment before the system sheet appears.

Files:

- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Core/RecoveryPeerVault.swift`
- `Numi Wallet/App/WalletAppModel.swift`
- `Numi Wallet/UI/WalletDashboardView.swift`

## Architectural Direction

### Authority iPhone

The authority iPhone remains the only normal spend-capable device.

It should own:

- long-lived authority identity
- day wallet
- vault chamber
- private receive and settlement composition
- recovery orchestration
- peer graph view
- session seal and redaction policy

It must not become:

- a market terminal
- a multi-chain asset browser
- a place where secret-bearing JSON remains normal

### Apple Watch

Apple Watch should remain a sentinel, not a wallet.

It should own:

- neutral readiness indication
- peer nearby indication
- session sealed indication
- remote seal action

It must not own:

- balances
- transaction history
- receive or send flow
- recovery fragments

### iPad

iPad should become the clearest recovery and co-presence peer.

It should own:

- presence approval
- fragment custody explanation
- recovery drill mode
- re-enrollment approval

It must not become:

- a second authority wallet
- a second day-spend surface

### Mac

Mac should become the diagnostics peer and recovery operator console.

It should own:

- trust record administration
- recovery approval
- diagnostics and audit-friendly state
- proof queue visibility and benchmark reporting sourced from the authority iPhone

It must not become:

- the canonical signer
- a remote dependency for normal use
- a required proof coprocessor

## State Of The Art Technical Plan

### Phase A: Harden The Existing iPhone Authority Shell

Target: next major implementation cycle

1. Replace remaining raw recovery text handling with bounded transfer surfaces.
   - Prefer authenticated local transfer between Apple devices.
   - The text editor should become a last-resort debug bridge, not a normal product flow.
2. Keep iPhone privileged entry points on `LAContext` and Keychain-gated system sheets.
   - Vault chamber entry.
   - Recovery import and export approval.
   - Panic or destructive custody actions where appropriate.
3. Move from a single `WalletDashboardView` monolith toward role-specific root shells.
   - `AuthorityPhoneRootView`
   - `RecoveryPeerRootView`
   - `MacPeerConsoleView`
4. Replace the `peerPresent` toggle with a real peer-trust abstraction.
   - Local session state
   - verified peer identity
   - spatial or proximity evidence
   - freshness window

### Phase B: Build The Real Apple Device Graph

1. Implement authenticated local peer sessions with `Network.framework`.
2. Layer `NearbyInteraction` on top for higher-confidence co-presence and precision.
3. Introduce a peer-trust record model with:
   - peer device identity
   - attestation state
   - last verified proximity
   - capability flags
   - revocation status
4. Replace recovery import and export staging with:
   - sender role
   - receiver role
   - explicit local approval
   - short-lived encrypted transfer session

### Phase C: Ship Role-Specific iPad And Mac Experiences

1. iPad peer home for recovery and presence approval.
2. iPad recovery drill mode with large, explicit, role-labeled steps.
3. Mac diagnostics surface with bounded proof queue visibility, benchmark reporting, and recovery controls.
4. Mac diagnostics surface:
   - App Attest health
   - key material posture
   - peer records
   - protected-data and privacy event history

### Phase D: Productionize Privacy Rail And Coin Architecture

1. Replace Info.plist protocol toggles with a signed coin manifest.
   - capability matrix
   - remote service URLs
   - fee model
   - privacy posture
   - post-quantum posture
   - required wallet roles
2. Separate protocol adapters from the sovereign shell.
3. Require a coin-integration review checklist:
   - privacy viability
   - long-lived cryptographic posture
   - receive model viability
   - metadata leak profile
   - fee fingerprinting risk
   - relay and discovery fit

### Phase E: Complete Post-Quantum Product Integrity

1. Keep long-lived signing and identity on Apple-supported quantum-secure primitives.
2. Keep application-layer confidentiality on Apple HPKE and remote transport on Apple system TLS wherever the protocol requires long future secrecy horizons.
3. Separate:
   - long-lived authority identity
   - short-lived transport credentials
   - fee hotkeys
   - peer session identity
4. Add a formal crypto inventory document:
   - primitive
   - scope
   - lifetime
   - rotation trigger
   - Apple API or library source
   - replacement policy

## Immediate Code Priorities

These should be the next implementation decisions, in order:

1. Replace the remaining transitional workspace with authenticated local transfer over `Network.framework`, plus explicit sender and recipient approval surfaces.
2. Layer real `NearbyInteraction` session management and precision evidence onto the peer-trust session model.
3. Refactor the UI into role-specific root views.
4. Add trust records, peer administration, and revocation surfaces.
5. Keep biometric entry points on `LAContext` and Keychain-gated system sheets, with SwiftUI only framing the trust state before system authentication.
6. Signed coin manifest is now the runtime authority for coin capabilities and service topology. Keep it pinned to a bundled ML-DSA-87 trust root and regenerate it only through the offline signing path.
7. Split proving, remote-service policy, and coin-capability policy into clearer subsystems.

## Recommended Codebase Shape

The long-term codebase should converge toward this structure:

### App shell

- role-specific platform roots
- immersive privilege surfaces
- event-driven operator history
- presentation and privacy policy layer

### Security core

- authority key management
- peer identity and attestation
- vault wrapping and keychain policy
- local authentication orchestration
- privacy lifecycle enforcement

### Device graph

- local transport
- proximity and co-presence
- trust records
- recovery transfer sessions
- proof queue visibility and benchmark capture

### Coin and protocol domain

- signed coin manifests
- capability adapters
- discovery
- relay
- PIR
- proving
- fee model

### Product telemetry

None for third parties.

If internal diagnostic logging is added, it should be:

- device-local by default
- explicit to reveal
- redacted by policy
- never balance-forward in notifications or system surfaces

## Exit Criteria For A Serious 1.0

Numi should not be considered serious until all of the following are true:

1. Authority keys are hardware-bound and non-exportable.
2. Recovery no longer depends on plaintext editable JSON as a normal workflow.
3. Peer presence is cryptographically or spatially grounded, not simulated by a toggle.
4. The iPad and Mac roles are real product surfaces, not just ideas in a roadmap.
5. Coin integration is manifest-driven and review-gated.
6. The wallet’s PQ posture is documented and enforced by design, not implied by marketing copy.
7. The iPhone experience feels unmistakably Apple-native and privacy-native.

## Bottom Line

The correct path forward is not to make Numi more generic. It is to make it more opinionated.

That means:

- more Apple-native
- more explicit about trust boundaries
- more structured in privileged flows
- more aggressive about privacy posture
- more honest about protocol capabilities
- more deliberate about post-quantum architecture

Numi wins by being the best sovereign wallet for Apple hardware, not by becoming a broader but weaker crypto app.
