# Numi Wallet Architecture And Roadmap

Last updated: April 5, 2026

See also:

- [Numi Apple Ecosystem Design Roadmap](NUMI_APPLE_ECOSYSTEM_DESIGN_ROADMAP.md)
- [Numi State Of The Art Apple Plan](NUMI_STATE_OF_THE_ART_APPLE_PLAN.md)

## Mission

Numi Wallet is an Apple-only, self-custody wallet focused exclusively on privacy-preserving and post-quantum-safe crypto systems.

Numi is not trying to be a universal crypto container, a multi-chain asset browser, or a trading product. It is a sovereign instrument for users who want the strongest available combination of:

- self-custody
- metadata resistance
- device-local trust
- post-quantum cryptographic posture
- Apple-native security and UX

The product should feel uncompromising. If a convenience feature weakens sovereignty, privacy, or post-quantum safety, Numi should refuse it.

The product is defined by four non-negotiable rules:

1. Non-exportable hardware-backed authority keys on the iPhone.
2. Local-only quorum recovery using user-owned Apple devices.
3. Private offline receive without reusable public addresses.
4. Device-seizure resistance through compartmentalization, redaction, and panic behavior.

The wallet is intentionally harder to use than a mass-market wallet. That friction is part of the security model, not a defect.

## Numi Thesis

Numi should be documented and built as a state-of-the-art iOS wallet, not as a generic app with crypto attached.

That means:

- iPhone is the authority surface because it is the strongest combination of Secure Enclave, LocalAuthentication, App Attest, and continuous user presence in the Apple ecosystem.
- Privacy is enforced at the protocol boundary and the product boundary. We do not treat privacy as a settings page.
- Post-quantum safety is treated as a live design constraint now, not a migration plan for later.
- The wallet shell must stay adaptable to future privacy coins and settlement rails without forcing every coin to implement the same transport stack.
- Advanced protocol machinery such as PIR, tag ratchets, hidden-fee markets, blinded discovery, and relay envelopes should be first-class capabilities, but they should be activated per coin profile rather than hard-coded as universal runtime assumptions.

This is the core design decision behind the current codebase direction: Numi has a single sovereign iOS shell with a strict doctrine, while coin-specific privacy features are plugged in through explicit capability gates.

## Product Doctrine

### UX Doctrine

Numi should feel like a sovereign instrument, not a finance dashboard.

- The iPhone is the authority device and root of trust.
- The Mac and iPad are peers with tightly bounded roles, not secondary wallets.
- Apple Watch is a companion surface for neutral status and deliberate prompts, not a signer, wallet, or recovery peer.
- The day wallet is the visible operating surface.
- The vault is hidden by default and should only appear when policy is satisfied.
- Sensitive material should move through bounded, purpose-built flows, never through generic text fields, reusable export formats, or cloud storage.
- The app should be quiet by default: no analytics, no third-party SDKs, no balance leaks in notifications, no widget surfaces, no Siri or Spotlight indexing of sensitive entities.
- Every privileged flow should make the trust boundary obvious: which device is approving, which device is proving, and why the user is being asked to authenticate.

### Security Doctrine

- Canonical spend authority lives only on the authority iPhone.
- Recovery peers may help unwrap or re-enroll, but they are not normal spend signers.
- Remote services are transport utilities, not trust anchors.
- Metadata minimization is a first-class property of the protocol, not a logging preference.
- Memory hygiene matters. Secrets should prefer Secure Enclave, keychain, or sealed blobs over long-lived heap objects.

### Protocol Doctrine

- Numi should support only coins whose architecture can be made compatible with a sovereign, privacy-preserving, post-quantum-forward wallet model.
- Address reuse, transparent account graphs, public counterparties, or fee flows that unavoidably fingerprint the user should be treated as design debt.
- Coin-specific features belong behind capability flags and protocol adapters, not in the app shell.
- If a coin supports PIR state refresh, tag ratchets, hidden-fee commitments, or blinded discovery, Numi should expose that cleanly.
- If a coin does not support those features, Numi should still run, but the UI must describe those capabilities as inactive rather than pretending they exist.

## Canonical Platform Stack

Numi should lean into Apple’s native stack rather than abstracting away from it.

- `CryptoKit` and Secure Enclave for authority signatures, sealed state, and local cryptographic operations.
- Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and access control flags for device-only secret retention.
- `LocalAuthentication` for device-owner authentication and spend gating.
- `DeviceCheck` App Attest for server-side client validation.
- `Network.framework` for local peer transport and bounded local sessions.
- `NearbyInteraction` for physical co-presence signals where available.
- `Metal` for proving, scanning, and heavy local cryptographic workloads.
- SwiftUI for the shell and policy-driven redaction, with runtime privacy behavior enforced below the view layer.

Apple references relevant to the current direction:

- [Local Authentication](https://developer.apple.com/documentation/localauthentication/)
- [LocalAuthenticationView](https://developer.apple.com/documentation/localauthentication/localauthenticationview)
- [Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [URLSessionConfiguration.ephemeral](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral)
- [applicationProtectedDataWillBecomeUnavailable(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationprotecteddatawillbecomeunavailable%28_%3A%29)
- [UIScene.didEnterBackgroundNotification](https://developer.apple.com/documentation/uikit/uiscene/didenterbackgroundnotification)
- [Privacy in the Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Get ahead with quantum-secure cryptography (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/314/)
- [Enhancing your app’s privacy and security with quantum-secure workflows](https://developer.apple.com/documentation/cryptokit/enhancing-your-app-s-privacy-and-security-with-quantum-secure-workflows)
- [Storing CryptoKit keys in the Keychain](https://developer.apple.com/documentation/CryptoKit/storing-cryptokit-keys-in-the-keychain)

## Current Design Choices

The current implementation makes a few foundational choices that should remain stable unless there is a very strong reason to change them.

### 1. Apple-Only By Design

Numi is not cross-platform. This is deliberate.

- Secure Enclave-backed authority keys are central to the trust model.
- LocalAuthentication and keychain access control are central to spend and recovery gating.
- App Attest is part of the remote abuse-resistance model.
- BackgroundTasks, scene lifecycle, capture handling, and protected-data transitions are part of privacy posture.

If we abstract these away in the name of portability, we weaken the wallet.

### 2. Capability-Gated Coin Features

The app no longer assumes that every supported coin must require:

- alias discovery
- PIR state refresh
- shared-secret tag ratchets
- dynamic fee markets
- relay submission

Instead, these are modeled as explicit protocol capabilities in the runtime configuration. The sovereign shell remains stable while each future coin can opt into only the privacy machinery it actually supports.

This is the right design because Numi is meant for the future of sovereign crypto, not for one protocol snapshot frozen in time.

### 3. PQ Safety With Practical Hybrid Boundaries

The codebase currently uses Apple’s post-quantum signature support for authority and fee-hotkey signing, while still using practical transport and key-agreement patterns appropriate to the current iOS stack.

The product stance is:

- prefer post-quantum-safe primitives for long-lived signing and identity where Apple supports them well
- use Apple-native secure storage for long-lived keys
- avoid inventing custom cryptographic primitives when Apple already provides a safe and reviewed path
- keep network and coin adapters flexible enough to adopt stronger post-quantum transport patterns as supported rails mature

### 4. Privacy Features Must Improve UX, Not Just Protocol Purity

PIR, tag ratchets, and hidden-fee designs matter because they should enable a better sovereign UX:

- no long “sync before you can pay” delay
- no reusable public identity
- no obvious metadata leaks in fee choice
- no giant local blockchain scan burden on the phone

If a privacy feature makes the wallet harder to operate without delivering a meaningful metadata win, it should be questioned.

## Current Repository State

The current repo is a prototype shell with meaningful security structure already in place.

### Implemented

- Authority/day/vault split with policy-gated vault visibility and spend.
- Secure Enclave-backed authority and peer signing keys, with simulator fallback.
- Device-only vault wrapping key and spend approval token in the keychain.
- Role-scoped and device-scoped canonical wallet state files.
- State integrity sealing to reject tampered wallet state.
- Short-lived peer-trust sessions with attested transcript fingerprints and expiry windows.
- Signed, role-bounded recovery transfer envelopes for peer-share and authority-bundle staging.
- Sealed local trust-ledger persistence for peer records and signed recovery-transfer audit history.
- App Attest-aware discovery and relay clients.
- Ephemeral URL session configuration for remote traffic.
- Privacy shield and runtime response to capture, screenshots, and protected-data loss.
- Runtime Apple security posture telemetry for Secure Enclave, owner authentication, App Attest, Nearby Interaction, local-state hardening, and privacy-boundary readiness.
- Key migration of descriptor private keys out of serialized wallet state into device-only keychain storage.
- Local-only recovery shares stored on peers under biometry/passcode protection.
- Capability-gated protocol configuration so advanced privacy features are opt-in per coin profile.
- Shielded wallet state model for note witnesses, PIR sync status, fee posture, and tag-relationship tracking.
- PIR client wiring for Merkle path refresh, nullifier checks, and tag lookup.
- Shared-secret tag-ratchet engine plus device-only ratchet secret storage.
- Dynamic-fee authorization path with fee commitment and authorized hotkey bundle construction.
- Background-refresh wiring for PIR-enabled coins on iOS.

### Partially Implemented

- Pairing invitation and attested transcript model.
- Peer trust is modeled and enforced locally, but still needs real `Network.framework` session transport and Nearby Interaction evidence.
- Role-specific roots exist at app entry, but the deeper surfaces still need to diverge further by device role.
- Metal-backed proving prototype.
- Recovery package generation and re-enrollment.
- Discovery and relay envelope padding and attestation attachment.
- Shielded send pipeline that now depends on real remote services instead of prototype local fallbacks.
- Coin capability model that is runtime-ready but still configured through Info.plist rather than a richer signed coin manifest.

### Not Yet Implemented

- Real `Network.framework` local pairing service and authenticated peer sessions.
- Production coin adapters for real settlement rails.
- Real receive decryption, note parsing, and witness construction against live protocol specs.
- Real zero-knowledge proving backend for fee commitments and spends.
- Mac proof-coprocessor protocol.
- Production-grade recovery UX that fully eliminates the transitional workspace.
- Dedicated iPad and Mac peer UX tuned to their roles.
- Dedicated Apple Watch companion UX tuned to its sentinel role.

## Current Implementation Record

This section documents the most important design choices reflected in the current source tree.

### Wallet State

- `WalletProfile` is the canonical persisted profile.
- Descriptor private material is stored out-of-line in device-only keychain storage.
- Ratchet secrets are stored separately from profile state for the same reason.
- Vault state is sealed and only rehydrated under local device-owner approval.
- The dashboard is a derived view of policy state and wallet state, not the source of truth.

### Protocol Features

- PIR, tag ratchets, dynamic fees, discovery, and relay submission are modeled as capabilities.
- The wallet should render inactive capabilities honestly instead of presenting broken actions.
- PIR-enabled spend now depends on fresh witness state, because “open and pay immediately” is only valid if the note witness and spent-status cache are current.
- Tag ratchets are treated as relationship state, not as stateless tags generated ad hoc.
- Dynamic fees are represented as a bundle containing quote, commitment, hotkey authorization, and settlement data.

### Remote Services

- Remote services are optional at app boot.
- They become required only when a selected coin profile enables the corresponding feature.
- This is the correct compromise between future extensibility and protocol honesty.

### UX and Product Surface

- The UI should communicate that Numi is a sovereign operating surface, not a portfolio dashboard.
- Unsupported features for the active coin profile should read as inactive, not unavailable due to app failure.
- Vault absence is preferable to vague partial disclosure.
- Recovery remains local, physical, and device-bounded.

## Architecture

### Device Topology

- Authority iPhone
  - Holds the long-lived authority key in the Secure Enclave.
  - Holds the canonical wallet profile.
  - Is the only normal signer.
- Recovery iPad
  - Stores one recovery fragment in device-only protected storage.
  - Provides mobile peer presence and recovery approval.
- Recovery Mac
  - Stores the second recovery fragment in device-only protected storage.
  - Provides the best proof offload target because of thermals and GPU budget.
- Apple Watch companion
  - Mirrors neutral state and deliberate prompts from the authority iPhone.
  - Must not hold recovery fragments, authority keys, or standalone spend capability.

### Trust Boundaries

- Secure Enclave boundary
  - Authority signatures should remain non-exportable.
- Keychain boundary
  - Descriptor receive secrets, recovery shares, wrapping keys, integrity keys, and App Attest key IDs belong here.
- Canonical profile boundary
  - Wallet profile files may contain descriptors and encrypted vault blobs, but should not contain plaintext descriptor private keys or recovery fragments.
- Local peer boundary
  - All quorum recovery and proof delegation should stay inside user-owned devices over local authenticated channels.
- Remote boundary
  - Discovery and relay only handle padded envelopes and blinded lookups.
  - Remote endpoints must verify App Attest and reject replay or downgrade paths.

### Public Interfaces

- `RootWalletVault`
  - Owns authority wallet initialization, descriptor rotation, spend authorization, recovery package creation, and vault memory management.
- `RecoveryPeerVault`
  - Owns peer share import/export and peer-side authorization.
- `DescriptorSecretStore`
  - Owns device-only storage of descriptor private material.
- `WalletStateStore`
  - Owns serialized canonical state, backup exclusion, and integrity sealing.
- `PairingChannel`
  - Owns invitation generation and attested session transcript structure.
- `DiscoveryClient` and `RelayClient`
  - Own the only remote-facing traffic.
- `PolicyEngine`
  - Owns visibility, spend, panic, and privacy-redaction policy.
- `LocalProver`
  - Owns the local Metal/CPU proving lane.

## UX Architecture

### First-Run

The first-run experience should do three things and nothing more:

1. Establish the authority iPhone as root of trust.
2. Explain that there is no seed phrase and no cloud recovery.
3. Immediately guide the user into enrolling the iPad and Mac peers.

The user should leave setup understanding the device topology. The UI should make it obvious that recovery is physical and local.

### Daily Operation

The day wallet should optimize for clarity and low cognitive load.

- Open with standard device-owner authentication.
- Show limited balances and active day receive state.
- Keep vault state absent, not merely collapsed.
- Let the user receive privately without learning protocol details.

### Vault Access

Vault access should feel ceremonial and explicit.

- Require local authentication on the authority iPhone.
- Require a cryptographically fresh peer-presence assertion.
- Show why the vault is hidden and what conditions are missing when access fails.
- Clear vault session state aggressively on background, capture, protected-data loss, or panic.

### Receive UX

Numi needs three receive surfaces:

1. Local QR/NFC/AirDrop-style receive for direct physical exchange.
2. Remote alias resolution to a fresh offline receive descriptor.
3. Receive inbox and scan flow that explains progress without exposing identifiers.

The UI should never teach the user that they “have an address”. They have rotating receive intents and descriptors.

### Recovery UX

The current plaintext recovery workspace is a prototype convenience and should not ship.

Shipping UX should replace generic text editing with:

- Peer-to-peer transfer over local authenticated channels.
- QR chunk export/import for human-assisted transfer.
- Explicit role-specific screens on iPad and Mac for “hold fragment”, “approve re-enrollment”, and “confirm presence”.

### Notification UX

Numi should use the weakest viable notification surface.

- Default to no notifications for balances, counterparties, or receive identifiers.
- If a reminder is needed, use passive notifications with neutral wording.
- Never leak sensitive content in push payloads, titles, or previews.

## Technical Direction To State Of The Art

### 1. Replace Manual Peer Presence With Cryptographic Presence

Current repo state still uses a manual `peerPresent` toggle. This is the largest architectural gap.

Target design:

- Pairing establishes a long-lived peer identity and a bounded trust record.
- Vault unlock requires a short-lived peer presence token minted from a local authenticated session.
- Presence token contains:
  - peer device ID
  - peer role
  - transport type
  - issued-at and expiry
  - transcript digest
  - authority-verifiable signature
- Tokens should be invalid outside a very short time window.

This turns co-presence from operator input into a cryptographic fact.

### 2. Replace Recovery Text Workspace With Bounded Transfer Channels

Current repo state still stores recovery JSON in a Swift `String`.

Target design:

- Authority device prepares a sealed recovery transfer package.
- Package is rendered into QR chunks or sent over an attested local channel.
- Recovery peers import directly into secure storage without landing in editable text.
- The authority recovery flow consumes peer packages from QR/local session import buffers that are bounded and immediately scrubbed.

### 3. Build Real Local Session Infrastructure

`PairingChannel` should evolve into a real local session subsystem.

Target design:

- `Network.framework` local listeners and browsers.
- Mutual transcript verification with app attestation attached where applicable.
- Session key derivation bound to invitation ID, device IDs, and transcript digest.
- Explicit session roles:
  - recovery approval
  - vault presence
  - proof offload
  - receive handoff

### 4. Build The Real Receive Scanner

Current repo stores descriptors and rotates them, but there is no production receive engine.

Target design:

- Descriptor secret lookup from keychain only when needed.
- Scanning pipeline that batches candidate ciphertext work.
- Metal-accelerated trial decryption and note discovery.
- Bounded memory arena for ciphertext candidate processing.
- Explicit scrub at the end of scan windows.

### 5. Build The Real Spend Engine

Current spend flow is a prototype envelope submission path.

Target design:

- Shielded note selection.
- Fee and change computation.
- Preflight policy checks before local auth prompt.
- Build proof witness locally.
- Sign only after proof and transaction body are finalized.
- Relay submit only after attestation and envelope padding are attached.

### 6. Mac Proof Coprocessor

The Mac should be the preferred local accelerator, but never a remote trust dependency.

Target design:

- Proof jobs signed and bound to authority wallet state digest.
- Witness fragments encrypted to a paired Mac session key.
- Response digest bound to the job ID and transcript digest.
- Authority iPhone remains the verifier of returned work before signing.

### 7. Role-Specific Apps

The single prototype shell should split into role-shaped experiences.

- iPhone:
  - authority wallet
  - receive, spend, vault, recovery orchestration
- Apple Watch:
  - wrist companion
  - neutral alerts, presence handoff, and session sealing
- iPad:
  - presence and recovery peer
  - mobile companion for vault unlock and peer approval
- Mac:
  - recovery peer
  - proof coprocessor
  - advanced diagnostics and peer administration

The shared wallet core should remain common, but the UI should not pretend every device is the same app with a different toggle.

### 8. Production Privacy Surfaces

Before shipping:

- remove generic editable recovery buffers
- audit every string that can contain sensitive material
- avoid storing decrypted or resolved payloads in long-lived observable state
- verify app switcher, capture, screenshot, and lock handling on-device
- set file protection and protected-data behavior across all persisted artifacts

### 9. Server Contract Hardening

Remote services must be deliberately stupid and verifiable.

Discovery service requirements:

- blinded alias token lookup
- attestation verification
- replay window enforcement
- fixed-size body acceptance
- no stable outward identity linkage

Relay service requirements:

- ingress/egress separation
- attestation verification
- replay and release-slot enforcement
- padded body acceptance
- no plaintext transaction visibility

### 10. External Review And Audit Readiness

State-of-the-art here means reviewability, not just cleverness.

Before launch:

- threat model document
- protocol document
- memory-handling document
- App Attest backend verification spec
- local pairing protocol spec
- red-team review of coercion and seizure resistance
- security code audit of the wallet core

## Roadmap

### Phase 0: Prototype Hardening

Status: In progress

Completed:

- device-scoped state
- integrity-sealed profile persistence
- App Attest-aware remote clients
- descriptor private key migration to keychain
- runtime privacy scrub paths

Remaining:

- remove plaintext recovery text workflow
- remove manual peer presence input
- add explicit memory-pressure handling

### Phase 1: Local Trust Fabric

Deliverables:

- authenticated `Network.framework` pairing sessions
- cryptographic peer-presence assertion
- peer trust records with rotation and revocation
- local transfer channels for recovery and descriptor exchange

Exit criteria:

- vault unlock depends only on cryptographic co-presence, not UI state

### Phase 2: Receive Pipeline

Deliverables:

- descriptor registry and key lookup path
- local inbox scan engine
- Metal-accelerated trial work
- receive history model with strict redaction policy

Exit criteria:

- full offline receive flow works locally without leaking reusable identifiers

### Phase 3: Spend And Proof

Deliverables:

- note selection and transaction construction
- proof witness builder
- on-device proof generation
- paired Mac proof offload
- final spend approval flow

Exit criteria:

- iPhone can prove and submit alone
- Mac can accelerate but never replace authority

### Phase 4: Recovery Productization

Deliverables:

- QR and local transfer-based recovery sharing
- peer approval UX on iPad and Mac
- authority re-enrollment UX on a new iPhone
- panic and re-entry drills

Exit criteria:

- no recovery path depends on plaintext text editing or cloud state

### Phase 5: App Store Readiness

Deliverables:

- role-specific app experiences
- accessibility pass
- HIG-aligned copy and flows
- security review package
- backend contract verification harness
- on-device test matrix across current public hardware

Exit criteria:

- App Store-ready sovereign wallet with explicit reviewable security invariants

## Immediate Engineering Priorities

If the team executes only the highest-leverage next steps, they should be:

1. Replace `peerPresent` with cryptographic peer-presence assertions.
2. Delete the recovery `TextEditor` flow and replace it with bounded transfer paths.
3. Build the local `Network.framework` session layer for pairing, approval, and presence.
4. Implement the real receive scanning and note ingestion path.
5. Build the real spend/proof pipeline and Mac proof offload protocol.

## Definition Of Done For Numi 1.0

Numi 1.0 is done when all of the following are true:

- The authority root never leaves the iPhone Secure Enclave.
- Canonical wallet state contains no plaintext descriptor private keys or recovery fragments.
- The vault is invisible and unusable without local auth and a real paired-peer presence assertion.
- Recovery works only with the configured peer quorum over local authenticated channels.
- Remote discovery and relay reject unattested or replayed clients.
- All remote payloads are padded, release-batched, and metadata-minimized.
- Sensitive state is cleared on background, capture, protected-data loss, and panic.
- The receive and spend flows operate without teaching the user a reusable public address model.
- The product has been documented well enough for an external security review to succeed.
