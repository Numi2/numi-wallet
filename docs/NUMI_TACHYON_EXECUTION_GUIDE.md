# Numi Tachyon Execution Guide

Last updated: April 5, 2026

See also:

- [Numi Future Of Crypto Roadmap](NUMI_FUTURE_OF_CRYPTO_ROADMAP.md)
- [Numi Architecture And Roadmap](NUMI_ARCHITECTURE_AND_ROADMAP.md)
- [Numi State Of The Art Apple Plan](NUMI_STATE_OF_THE_ART_APPLE_PLAN.md)
- [Numi Ragu iOS Invention](NUMI_RAGU_IOS_INVENTION.md)

## Purpose

This guide is the execution companion to the future-of-crypto roadmap.

It is written so an AI developer or a new engineer can move the Tachyon-readiness program forward without having to infer:

- what comes first
- what must remain configurable
- where the hard technical boundaries are
- what state must exist before the next subsystem is started
- how to know a workstream is complete enough to unblock the next one

This is not a protocol spec for Tachyon. It is Numi's implementation plan for becoming Tachyon-ready while the protocol is still evolving.

## Current Shipping Restriction

For the current Tachyon program, Numi is iOS only.

This is the source of truth for the current milestone.

That means:

- the shipping target is the iPhone app on iOS
- macOS, watchOS, visionOS, and companion-device trust flows are out of scope for the current Tachyon-ready milestone
- no part of the current Tachyon milestone may depend on a Mac proof lane, watch approval lane, or companion-device local-auth path
- if the repo still contains broader Apple-platform traces, they are cleanup debt, not product scope

Important current-repo note:

- `Numi Wallet.xcodeproj/project.pbxproj` still lists non-iOS supported platforms
- AI developers should not treat that as permission to design a multi-platform Tachyon rollout

## How To Use This Guide

1. Start from the dependency order in this document, not from whichever subsystem looks most interesting.
2. Treat every protocol assumption that is not pinned by a test vector, public spec, or manifest version as configurable.
3. Do not couple the SwiftUI shell to Tachyon internals. Keep Tachyon-specific logic behind adapter and capability boundaries.
4. When a step says "do not continue until", stop there. Those are real dependency gates.
5. For every technically difficult subsystem, implement the state model and test harness before implementing the product surface.
6. Treat iOS background scheduling as best-effort. Design for truthful degradation, not magical reliability.

## Apple iOS Capability Map

These Apple platform capabilities are the authoritative building blocks for the current Tachyon program.

Verified in the installed Xcode 26.4 / iPhoneOS 26.4 SDK:

- `CryptoKit.SecureEnclave.MLDSA87`
- `CryptoKit.MLDSA87`
- `CryptoKit.XWingMLKEM768X25519`
- `CryptoKit.HPKE.Ciphersuite.XWingMLKEM768X25519_SHA256_AES_GCM_256`
- `BGAppRefreshTaskRequest`
- `BGContinuedProcessingTaskRequest`
- `BGContinuedProcessingTaskRequest.Resources.gpu`

Verified missing from the installed iPhoneOS 26.4 SDK:

- `LocalAuthenticationView`

Platform capabilities Numi should rely on:

- `LAContext` for device-owner authentication
- Keychain with device-only accessibility for long-lived secret material
- Secure Enclave `MLDSA87` for the authority root
- DeviceCheck App Attest for remote request authenticity
- `BGAppRefreshTaskRequest` for best-effort PIR readiness maintenance
- `BGContinuedProcessingTaskRequest` for user-initiated long proof work
- `UIApplicationProtectedDataWillBecomeUnavailable`
- `UISceneDidEnterBackgroundNotification`
- `URLSessionConfiguration.ephemeral`
- Apple system TLS

Platform capabilities Numi should not depend on for the current program:

- `LocalAuthenticationView`
- companion-device local authentication
- proof offload to non-iOS peers
- watch-mediated approval
- non-Apple TLS stacks

Apple references:

- Local Authentication: <https://developer.apple.com/documentation/localauthentication/>
- App Attest server validation: <https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server>
- BackgroundTasks: <https://developer.apple.com/documentation/backgroundtasks>
- Secure Enclave: <https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave>
- Storing CryptoKit keys in the Keychain: <https://developer.apple.com/documentation/cryptokit/storing-cryptokit-keys-in-the-keychain>
- Quantum-secure workflows: <https://developer.apple.com/documentation/cryptokit/enhancing-your-app-s-privacy-and-security-with-quantum-secure-workflows>
- Quantum-secure TLS: <https://developer.apple.com/documentation/network/preparing-your-network-for-quantum-secure-encryption-in-tls>
- Ephemeral URL sessions: <https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral>
- Protected data unavailable: <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationprotecteddatawillbecomeunavailable%28_%3A%29>

## Tachyon Requirements Synthesized For iOS

This section translates Tachyon's wallet-facing requirements into concrete iPhone product and engineering requirements for Numi.

### 1. Kill Shielded Sync On iPhone

Tachyon requirement:

- wallets should not replay the full chain locally just to become spend-ready

Numi iOS interpretation:

- the iPhone should keep a private readiness cache that is refreshed through PIR
- immediate-spend claims must be backed by fresh Merkle paths, fresh nullifier status, and a chain-state lease
- when iOS background scheduling does not cooperate, the app must truthfully fall back to "quick private refresh required"

Numi design:

- `PIR Readiness Lease`
  - a persisted record of trusted block height, anchor root, providers consulted, and expiry policy
- `Refresh Ticket Ledger`
  - a background-safe cache of precomputed query material, not of long-lived descriptor secrets
- `Dispute Quarantine`
  - if providers disagree, keep the last trusted state but block instant-spend claims

### 2. Shared-Secret Discovery On iPhone

Tachyon requirement:

- wallets discover payments through tags and ratchets rather than whole-chain scanning

Numi iOS interpretation:

- the iPhone must maintain relationship state like a private messaging client
- the wallet must survive app restarts and background scheduling without replaying relationship state incorrectly

Numi design:

- `Relationship Vault`
  - state machine plus ratchet cursors, lookahead window, replay ledger
- `Shielded Inbox Journal`
  - append-only ingestion pipeline for matches, decryptions, and note creation

### 3. Hidden Fee Markets On iPhone

Tachyon requirement:

- wallets commit to hidden maximum fees and authorize hotkeys to settle at live market rates

Numi iOS interpretation:

- the iPhone must separate proving from final market settlement so long proof work does not force the user to rebuild the whole send whenever a quote expires

Numi design:

- `Send Capsule`
  - a sealed, proof-ready transaction draft that survives quote expiry
- `Fee Grant`
  - a short-lived authorization scoped to one quote and one finalized draft digest

### 4. Recursive Proofs On iPhone

Tachyon requirement:

- wallets must support proof-bearing transaction assembly with evolving recursive proof formats

Numi iOS interpretation:

- default proving must run on the iPhone
- user-initiated long proof work should use iOS continued-processing facilities where possible
- the authority iPhone must verify proof artifacts before final approval

Numi design:

- `Proof Capsule`
  - a sealed proof job input with explicit digests and resumable progress
- `Continued Proof Lane`
  - a `BGContinuedProcessingTaskRequest`-backed path for long-running user-initiated proof jobs

### 5. Post-Quantum Address Resolution On iPhone

Tachyon requirement:

- large post-quantum identity documents resolve privately from compact identifiers

Numi iOS interpretation:

- the iPhone must treat counterparties as contact documents, not reusable addresses
- the UI must never keep giant documents resident in observable state longer than necessary

Numi design:

- `Contact Document Vault`
  - digest-pinned cached documents plus freshness and dispute state

### 6. Governance On iPhone

Tachyon requirement:

- wallets prove eligible, unspent balance for voting without moving funds

Numi iOS interpretation:

- governance must be a separate proof lane with checkpointed inputs and its own failure model

Numi design:

- `Governance Checkpoint Vault`
  - stores checkpoint height, proof inputs, and vote receipts separately from spend state

## What Is Firm Versus Uncertain

### Firm Enough To Build Around Now

- PIR-backed wallet readiness is central to Tachyon's public direction.
- Tachyon is explicitly separating payment delivery from the shielded protocol.
- Ragu and recursive proof-carrying data are central to the proof architecture.
- The local iPhoneOS 26.4 SDK exposes the PQ primitives and background-processing APIs Numi needs for an iPhone-only path.
- App Attest, Local Authentication, Keychain, scene lifecycle, and protected-data handling are all appropriate platform anchors for Numi.

### Still Uncertain Or Incomplete

- public Tachyon materials do not yet pin the final wallet wire format for every message and proof stage
- public materials do not yet fully specify a server-signing or slashing contract for PIR lies
- the final governance proof format is not public enough to hard-code today
- the exact PQ address publication and resolution semantics may still change
- operational availability of the `BGContinuedProcessingTaskRequest` GPU resource entitlement needs more product and deployment validation
- current Numi App Attest code generates assertions, but does not yet implement the full attest-key bootstrap flow Apple expects

Whenever one of these uncertain areas becomes concrete, update the adapter and manifest layer first, not the UI.

## Non-Negotiable Invariants

These invariants should be enforced throughout the execution plan:

1. The authority key remains on the authority iPhone.
2. Remote services are helpers, never trust anchors.
3. Protocol capabilities must be explicit in manifests and runtime state.
4. "No sync" cannot mean "blind trust in a server." It means private refresh with bounded verification strategy.
5. Relationship discovery state must be recoverable enough for normal wallet life, but must not collapse into a reusable address model.
6. The current shipping plan may not depend on a Mac, watch, or companion device.
7. Proof correctness verification on iPhone is mandatory.
8. Post-quantum migration must not be bolted on later. Data models introduced now must leave room for large identities and new key structure.

## Dependency Order

Do the work in this order:

1. Lock iOS-only scope and platform configuration
2. Establish the Tachyon lab
3. Capability model and manifest topology
4. Tachyon adapter boundary
5. PIR subsystem v2
6. Relationship and ratchet state machine
7. Shadow receive and note-ingestion pipeline
8. Fee privacy subsystem
9. Transaction builder and proof job contracts
10. Real proof integration on iPhone
11. Post-quantum address resolution
12. Governance and nullifier-proof lane
13. Pool migration product flow
14. Audit, benchmarks, and failure drills

This order matters.

Examples:

- Do not implement real Tachyon proving before the adapter boundary exists.
- Do not build shadow receive before the PIR and ratchet state models are stable.
- Do not build governance UI before governance checkpoint and proof input models exist.
- Do not rely on background refresh or continued processing before platform configuration, Info.plist keys, and entitlements are explicitly handled.

## Repo Baseline

The current codebase already gives the execution plan several useful anchors:

- `CoinProtocolCapabilities` and `RemoteServiceConfiguration` already gate protocol features.
- `PIRClient` and `ShieldedStateCoordinator` already model private state refresh.
- `TagRatchetEngine` and `RatchetSecretStore` already model relationship state at a primitive level.
- `DynamicFeeEngine` already has a placeholder bundle model for quote, commitment, hotkey, and settlement.
- `RootWalletVault` already contains the dominant authority-wallet orchestration boundary.
- `LocalProver` exists as the future proving seam.
- `BackgroundRefreshCoordinator` already schedules `BGAppRefreshTaskRequest`.
- `ScreenPrivacyMonitor` already reacts to capture and protected-data loss.

Current repo gaps that matter for Tachyon on iOS:

- no explicit iOS-only Tachyon scope lock in build settings or docs
- `Config/NumiWallet-Info.plist` now carries the background task identifiers, but there is still no checked-in entitlements file for Tachyon-critical platform features
- no full App Attest bootstrap and attestation-registration lifecycle
- no real proof backend for recursive shielded spends
- no explicit proof execution context separating foreground, continued-processing CPU, and continued-processing GPU grants
- no chunked GPU prover that can publish progress and stop cleanly on expiration
- the Tachyon adapter boundary is present, but still mock-heavy and not yet bound to a production proving backend

That means the right next move is not "start proving." The right next move is "stabilize scope, the adapter boundary, and the state model so everything else can land cleanly."

## Step 0: Lock iOS-Only Scope And Platform Configuration

This is the first execution step because the current repo still carries broader platform traces.

Primary files:

- `Numi Wallet.xcodeproj/project.pbxproj`
- `Config/NumiWallet-Info.plist`
- future entitlements file

Current problem:

- supported platforms still include non-iOS entries
- the checked-in Info.plist now includes background task identifiers, but the biometric usage copy and entitlement wiring are still incomplete
- entitlements for App Attest and continued-processing GPU experiments are not yet explicit in the repo

Tasks:

1. Treat `iphoneos` and `iphonesimulator` as the only supported platforms for the current Tachyon program.
2. Decide whether iPad remains supported as the same iOS binary or whether the shipping target is iPhone-only. Document that choice in the project and docs.
3. Add or verify these iOS configuration items:
   - `BGTaskSchedulerPermittedIdentifiers`
   - `NSFaceIDUsageDescription`
   - App Attest environment entitlement if required by the deployment setup
   - continued-processing GPU entitlement only if the product truly intends to ship a GPU-enabled background proof lane
4. Remove any planning dependency on macOS, watchOS, or visionOS features from the Tachyon milestone.
5. Document the current minimum iOS version required for:
   - PQ primitives
   - App Attest
   - app refresh
   - continued processing

Do not continue until:

- the product scope is explicitly iOS-only in docs
- background-task identifiers and biometric usage descriptions are part of the build configuration story
- AI developers no longer have to guess whether Mac or watch paths are in scope

## Step 1: Establish The Tachyon Lab

This is mandatory before any major subsystem work.

Deliverables:

- a `tachyon-testnet` manifest profile
- a local mock service bundle for PIR, relay, fee quote, and future address resolution
- fixture files for notes, nullifiers, Merkle paths, tags, and transaction/proof placeholders
- a benchmark harness for PIR refresh and proof-job envelopes

Tasks:

1. Create a dedicated manifest payload under `docs/manifests/` for Tachyon testnet.
2. Define service endpoint placeholders for:
   - PIR Merkle paths
   - PIR nullifier checks
   - PIR tag checks
   - relay ingress
   - relay egress
   - fee quote
   - future address resolution
3. Add scripts or fixtures that can produce deterministic mock responses by block height.
4. Ensure fixture responses are stable enough for golden tests.
5. Add a single command or script entry point that boots the local test environment.

Do not continue until:

- the app can load the Tachyon manifest
- a local harness can return deterministic PIR responses
- the team has at least one golden state-refresh fixture

## Step 2: Capability Model And Manifest Topology

This is the first major code change that should land.

Primary files:

- `Numi Wallet/Models/WalletModels.swift`
- `Numi Wallet/Models/CoinManifestModels.swift`
- `Numi Wallet/Core/CoinManifestLoader.swift`
- `Numi Wallet/NumiCoinManifest.json`
- `docs/manifests/`

Current problem:

- `CoinProtocolCapabilities` is too small and boolean-only
- Tachyon needs more than yes/no toggles; it needs feature families and service topology that can evolve without breaking the app shell

Implement in this order:

1. Introduce named capability groups.
   - state refresh
   - discovery
   - fee privacy
   - relay submission
   - address resolution
   - governance
   - migration
2. For each group, add a mode or version field rather than only a boolean.
3. Keep a compatibility layer so the current preview manifest still loads.
4. Add service topology for distinct PIR classes instead of a single PIR bucket where needed.
5. Add manifest validation rules that reject impossible combinations.

Examples of invalid combinations:

- tag-based discovery enabled without a tag-capable PIR route
- hidden-fee settlement enabled without fee quote and relay settlement topology
- governance enabled without a checkpoint or proof-input source

Acceptance checks:

- the manifest loader rejects invalid topology with explicit errors
- the dashboard can render inactive, partial, and active capability states
- the app can load a Tachyon profile without hard-coding Tachyon behavior into the shell

Do not continue until:

- the manifest can represent Tachyon without abuse of placeholder booleans
- runtime code can branch on capability mode instead of ad hoc string checks

## Step 3: Define The Tachyon Adapter Boundary

This is the most important architectural decision in the whole program.

Primary files:

- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Core/LocalProver.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- new Tachyon-specific modules under `Numi Wallet/Core/` and `Numi Wallet/Models/`

Current problem:

- `RootWalletVault` orchestrates shielded work, but there is no protocol adapter boundary that isolates Tachyon transaction semantics from the app shell

Create a dedicated adapter contract before implementing any real Tachyon logic.

The adapter should own:

- note decoding and note domain types
- witness requirements
- tag generation and interpretation specifics
- transaction assembly stages
- proof payload preparation
- relay payload encoding specific to the protocol

The shell should continue to own:

- authority approval
- secure storage
- policy gating
- capability gating
- UI state

Recommended interface slices:

1. `TachyonStateAdapter`
   - decode note payloads
   - produce nullifier query inputs
   - produce witness refresh requirements
2. `TachyonDiscoveryAdapter`
   - generate bootstrap queries
   - generate ratcheted query inputs
   - interpret tag matches
3. `TachyonTransactionAdapter`
   - turn wallet note state into protocol spend inputs
   - assemble bundle/action/stamp drafts
4. `TachyonProofAdapter`
   - define proof job input/output structures
   - define compression boundaries

Do not let:

- `WalletDashboardView`
- `WalletAppModel`
- `RootWalletVault`

learn Tachyon-specific field layout, proof layout, or stamp rules directly.

Do not continue until:

- there is a clean Swift protocol or module boundary for Tachyon-specific logic
- a mocked adapter can drive state refresh and draft transaction assembly without the real proof backend

## Step 4: PIR Subsystem V2

This is one of the hardest subsystems and needs more rigor than a transport client.

Primary files:

- `Numi Wallet/Networking/PIRClient.swift`
- `Numi Wallet/Core/ShieldedStateCoordinator.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- `Numi Wallet/App/WalletAppModel.swift`

### Problem Statement

Today the wallet can issue PIR-like requests. That is not enough.

For Tachyon readiness, Numi needs:

- provider-aware query routing
- freshness tracking by chain state, not just by time
- mismatch detection between deterministic responses
- degraded mode that is honest and reversible
- evidence capture when a provider lies or diverges

### iOS-Only Design Constraint

Background refresh on iOS is best-effort. It is not a daemon.

That means Numi cannot assume descriptor secrets will be available in the background, and cannot assume the scheduler will wake the app exactly when desired.

Use this design:

- keep long-lived descriptor and ratchet secrets in `WhenUnlockedThisDeviceOnly` storage
- precompute background-safe query material while the app is foregrounded and unlocked
- store only query tokens needed for refresh:
  - note commitments
  - nullifiers
  - ratchet lookahead tags
  - contact document identifiers
- persist those tokens in a short-lived `Refresh Ticket Ledger`
- derive wallet readiness from a `Readiness Lease`, not from the assumption that background refresh always ran

This is the core iOS invention that makes Tachyon's "no sync" goal compatible with strict key handling.

### Data Model Changes

Add explicit models for:

- PIR provider identity
- per-query-class provider policy
- query receipt
- signed response metadata
- mismatch event
- dispute evidence snapshot
- anchor-root freshness state
- `PIRReadinessLease`
- `PIRRefreshTicket`

Repository implementation note as of April 5, 2026:

- `PIRSyncSnapshot` now persists provider receipts, mismatch events, dispute evidence, a readiness lease, and a short-lived refresh-ticket ledger.
- `ShieldedStateCoordinator` now preserves the last trusted lease on stale or disputed responses and can fall back to cached discovery tickets during iOS background refresh.
- `WalletDashboardState` now surfaces readiness posture as `ready`, `stale`, `degraded`, or `disputed` instead of a binary refresh flag.
- True multi-provider compare-two and quorum verification are still future work; the current implementation records provider-scoped evidence and internal consistency failures first.

### Execution Order

1. Split `PIRClient` responsibilities:
   - transport
   - request encoding
   - response verification
   - provider selection
2. Add a provider registry in runtime configuration.
3. Introduce per-query-class policies:
   - single provider
   - compare-two
   - quorum
4. Attach block height, anchor root, provider ID, and response digest to every successful refresh.
5. Persist mismatch records instead of only throwing errors.
6. Teach `ShieldedStateCoordinator` to classify refresh results:
   - ready
   - stale
   - degraded
   - disputed
7. Teach the refresh coordinator to use only precomputed refresh tickets when protected data is unavailable.
8. When the app returns to foreground, reconcile refresh tickets against live secret state before claiming readiness.

### Verification Strategy

Treat query classes differently:

- Merkle paths:
  compare root, leaf index, anchor height, and sibling path digest
- Nullifier status:
  compare spent set and block height
- Tag matches:
  compare tag match set, ciphertext digest set, and block height
- Future address resolution:
  compare identifier-to-document mapping and document digest

### Failure Policy

If providers disagree:

1. record the mismatch
2. keep the old known-good refresh state if one exists
3. mark the wallet `disputed` rather than `ready`
4. disable immediate-spend claims until resolved

### Test Plan

Add tests for:

- identical provider responses
- one provider lying about one nullifier
- one provider returning an old block height
- one provider omitting a tag match
- response signature present but invalid
- no provider available
- protected data unavailable while refresh tickets exist
- no refresh tickets available for a background attempt

Do not continue until:

- refresh results are persisted with provider and chain-state context
- the app can distinguish stale from disputed
- immediate-spend posture is blocked when verification confidence is insufficient
- background refresh can run without loading long-lived descriptor secret material
- the wallet can say "quick private refresh required" without presenting it as failure

## Step 5: Relationship And Ratchet State Machine

This is the second hard subsystem. The main risk is accidental reinvention of a weak messaging protocol.

Primary files:

- `Numi Wallet/Core/TagRatchetEngine.swift`
- `Numi Wallet/Security/RatchetSecretStore.swift`
- `Numi Wallet/Core/ShieldedStateCoordinator.swift`
- `Numi Wallet/Core/RootWalletVault.swift`

### Problem Statement

The current implementation has the right primitives, but AI developers need a clear state machine.

Define relationship states explicitly:

1. `bootstrapPending`
2. `introductionSent`
3. `introductionReceived`
4. `activeBidirectional`
5. `rotationPending`
6. `stale`
7. `revoked`

### Required Persistent State

Persist separately:

- relationship metadata
- outgoing chain state
- incoming chain state
- lookahead cursor
- last accepted incoming tag
- replay window or replay digest set
- introduction material provenance

Repository implementation note as of April 5, 2026:

- `TagRelationshipSnapshot` now persists explicit relationship state, lookahead cursor state, last accepted incoming tag, ciphertext replay digests, and introduction provenance.
- `ShieldedStateCoordinator` now rejects replayed inbound matches before decryption, advances ratchets only after successful payload handling, and finalizes outbound relationship state after successful relay submission.
- The dashboard now summarizes relationship posture as new, active, stale, or rotating.
- Rotation is scaffolded in the persisted model but full relationship-rotation migration is still future work.

Do not conflate:

- contact identity
- receive descriptor
- ratchet material

On iOS specifically:

- do not store full contact documents or relationship state in observable UI models
- do not store plaintext introduction payloads in scratch text buffers
- precompute only bounded lookahead material for background use

### Execution Order

1. Define the relationship state machine in code and docs.
2. Add persistent lookahead windows so the wallet can query several future tags safely.
3. Add replay protection for accepted inbound matches.
4. Add rotation flow:
   - derive new relationship
   - preserve old state until new state is confirmed
   - seal off old state after confirmation
5. Add recovery/export behavior for relationship state that avoids generic plaintext export.

### Inbound Match Handling

When a tag match is received:

1. identify whether it belongs to a bootstrap tag or ratcheted lookahead
2. verify it is not a replay
3. decrypt payload
4. advance only the minimum necessary number of ratchet steps
5. persist the updated cursor and replay evidence
6. only then emit the received note into wallet state

Do not:

- advance ratchets before decryption succeeds
- accept the same tag twice
- allow bootstrap and established-relationship logic to share the same code path without explicit branching

### Test Plan

Add tests for:

- first contact
- multiple sequential inbound payments
- skipped-message lookahead
- replayed ciphertext for a previously accepted tag
- broken introduction payload
- relationship rotation while old lookahead tags still exist

Do not continue until:

- inbound discovery is replay-safe
- relationship state survives app restart
- the wallet can explain whether a contact is new, active, stale, or rotating

## Step 6: Shadow Receive And Note Ingestion

This is where the app starts becoming operationally useful before full spend support.

Primary files:

- `Numi Wallet/Core/ShieldedStateCoordinator.swift`
- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- Tachyon adapter modules

Execution order:

1. Add note payload fixtures and decoding harnesses through the Tachyon adapter.
2. Separate note discovery from note spendability.
3. Add a note-ingestion pipeline with these stages:
   - query generation
   - match receipt
   - ciphertext decryption
   - payload validation
   - note insertion
   - witness refresh
   - spendability classification
4. Persist partial progress so the wallet can recover from interruption.
5. Add dashboard posture that states whether a note is:
   - discovered
   - verified
   - witness-fresh
   - immediately spendable
6. Add a `Shielded Inbox Journal` so partial receive work can be resumed safely after termination or protected-data loss.

Do not continue until:

- shadow receive can ingest fixture notes end to end
- discovered notes and spendable notes are clearly separated in state and UI
- interrupted receive work can resume without duplicating notes

## Step 7: Fee Privacy And Hotkey Settlement

This subsystem is hard because it sits between wallet UX, remote services, and proof logic.

Primary files:

- `Numi Wallet/Core/DynamicFeeEngine.swift`
- `Numi Wallet/Networking/FeeOracleClient.swift`
- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`

### Problem Statement

The current `DynamicFeeEngine` is a useful placeholder, but it is not yet a protocol-authentic hidden-fee design.

The implementation must separate five concerns that are currently too close together:

1. user maximum fee intent
2. market quote
3. proof-backed hidden commitment
4. hotkey authorization
5. relay settlement and refund accounting

### iOS-Only Design Constraint

Long proof work and short fee-quote validity are in tension on iPhone.

Do not force the user to redo the whole send if only the quote expires.

Use this design:

- build a `Send Capsule` that contains:
  - selected notes
  - recipient resolution result
  - outgoing discovery material
  - draft digest
  - proof-ready witness digest
- keep the live fee quote and hotkey grant outside that capsule
- if a quote expires, preserve the capsule and re-run only the quote and final authorization path

### Required Data Boundaries

Keep these objects separate:

- `FeeIntent`
- `FeeMarketQuote`
- `HiddenFeeCommitment`
- `FeeHotkeyGrant`
- `FeeSettlementResult`
- `SendCapsule`

Do not use one bundle type internally for all logic just because the UI eventually displays one summary.

### Execution Order

1. Split the current authorization bundle flow into smaller internal stages.
2. Add explicit quote expiry and stale-quote rejection behavior.
3. Bind hotkey authorization to:
   - transaction digest or draft ID
   - quote ID
   - expiry
   - maximum allowed settlement scope
4. Add refund reconciliation state so the wallet can explain:
   - quoted fee
   - settled fee
   - returned difference
5. Keep the proof-backed commitment behind an adapter boundary so the real proving backend can replace the placeholder.
6. Persist proof-ready send capsules under device-only protection so user work survives non-destructive interruptions.

### Failure Cases To Model

- quote expired before submission
- relay settled at higher fee than authorized
- relay reports success but no refund reconciliation arrives
- hotkey reused outside scope
- user draft changes after quote but before signing

### Test Plan

Add tests for:

- valid quote and settlement
- expired quote
- authorization reuse
- transaction digest mismatch
- refund smaller than expected

Do not continue until:

- fee privacy state is modeled as a sequence, not one opaque bundle
- the UI can explain confidence and failure without exposing the maximum fee commitment
- quote expiry does not force reconstruction of the entire send intent

## Step 8: Transaction Builder And Proof Job Contracts

This is where most architecture collapses if the team is careless.

Primary files:

- Tachyon adapter modules
- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Core/LocalProver.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`

### Problem Statement

Tachyon's public repository already shows a separation between bundle/action/stamp. Numi must mirror that separation in its internal builder so proof aggregation changes do not leak into UI orchestration.

### Required Internal Stages

Define builder stages explicitly:

1. note selection
2. witness selection
3. recipient resolution
4. outgoing discovery and tag material
5. fee intent and quote
6. transaction draft assembly
7. proof capsule creation
8. proof attachment
9. local verification
10. authority approval
11. relay packaging
12. submission receipt and post-submit refresh

### Required Models

Add wallet-internal models for:

- `TachyonBundleDraft`
- `TachyonActionDraft`
- `TachyonStampDraft`
- `TachyonProofJob`
- `TachyonProofArtifact`
- `TachyonSubmissionEnvelope`
- `TachyonSendCapsule`

Keep these internal models decoupled from the final on-wire encoding if possible.

### iPhone Proof Contract

Define one proof contract for all iPhone proof lanes:

- foreground proof
- `BGContinuedProcessingTaskRequest` proof
- future resumed proof after interruption

The contract should include:

- job ID
- wallet state digest
- transaction draft digest
- witness digest
- quote-binding state if relevant
- expiry
- transcript digest
- returned proof artifact digest
- progress model

The proof lane may:

- compute proofs
- compress proofs
- return benchmark metrics

The proof lane may not:

- authorize spend
- mutate the canonical draft
- finalize the relay payload

### Verification Order

On the iPhone:

1. verify returned proof artifact structure
2. verify digest matches the requested job
3. verify proof against the local draft
4. only then request local user approval

Do not continue until:

- the iPhone remains the final verifier before spend authorization
- foreground and continued-processing proof jobs share the same contract

## Step 9: Real Proof Integration On iPhone

Only begin this after Steps 2 through 8 are complete.

Primary files:

- `Numi Wallet/Core/LocalProver.swift`
- Tachyon proof adapter modules

Execution order:

1. land a mock proof backend that obeys the real proof job contract
2. land a benchmarkable local proof runner
3. land a `BGContinuedProcessingTaskRequest` proof lane using the same contract
4. only then switch one pathway to the real proving backend

This staged approach matters because otherwise the team will blur:

- platform scheduling failures
- proof failures
- job-shape failures
- UI failures

### Recommended `BGContinuedProcessingTaskRequest` Model

Use continued processing only for user-initiated long proof work, never for silent background proving.

Recommended execution ladder:

1. start the proof in the foreground immediately so the user action always maps to visible progress
2. submit a continued-processing request only for proof jobs that are expected to outlive a background transition
3. keep CPU continued processing as the default background lane
4. request GPU resources only when the signed app has the entitlement, `BGTaskScheduler.supportedResources.contains(.gpu)` is true at runtime, and the proof job is chunked enough to publish progress and stop on expiration
5. if GPU submission is rejected or unsupported, retry the same checkpoint on continued-processing CPU or stay on the foreground or resumable lane
6. on expiration, persist the sealed proof capsule and mark the send as resumable

Architectural recommendation:

- separate proof lane from execution grant. A proof job may be `.foreground`, `.continuedProcessing`, or `.resumed`, but the prover still needs an explicit execution context such as foreground-unrestricted, continued-processing CPU, or continued-processing GPU
- forbid background Metal work unless the continued-processing request both asked for `.gpu` and the signed build is entitled to use it
- chunk GPU proving into bounded epochs that can publish progress regularly and checkpoint between epochs

Uncertainty:

- the GPU resource path requires the `com.apple.developer.background-tasks.continued-processing.gpu` entitlement
- not all devices support background GPU use, and runtime behavior under heavy GPU contention still needs empirical validation
- App Review and deployment expectations for this entitlement still need operational research

Fallback:

- if continued processing or GPU resources are unavailable, remain in the foreground or resumable proof path and communicate that clearly

Repository implementation note as of April 5, 2026:

- `TachyonProofCheckpoint` is now persisted in shielded wallet state with the sealed send capsule, proof job, progress timeline, returned artifact, and resumable status.
- `TachyonProofContinuationCoordinator` now registers an iOS continued-processing handler under a wildcard task identifier, reports progress through `NSProgress`, and submits with `.fail` semantics.
- `RootWalletVault.submitSpend` now checkpoints the send proof before execution, attempts a `BGContinuedProcessingTaskRequest` lane first, falls back to the foreground lane if immediate scheduling is unavailable, and keeps proof-ready or expired checkpoints persisted until authorization and relay submission complete. The current call site still submits with `requestGPU: false`.
- `RootWalletVault.resumePendingShieldedSend(checkpointID:...)` and `discardPendingShieldedSend(checkpointID:...)` now operate on specific persisted capsules: proof-ready checkpoints go straight to local authorization and relay submission, expired/queued/failed checkpoints rerun on the `resumed` lane before authorization, and discarding an unsent introduction capsule safely unwinds the bootstrap relationship instead of stranding it.
- The dashboard now exposes a real checkpoint browser for pending shielded sends, including per-capsule state, lane, freshness, resume/authorize actions, and destructive discard behind privileged local authentication.
- `Config/NumiWallet-Info.plist` now includes `BGTaskSchedulerPermittedIdentifiers` for app refresh and Tachyon proof wildcard identifiers, but there is still no checked-in entitlements file.
- `LocalProver` still attempts Metal whenever a device and pipeline are available. That is acceptable for foreground proofing, but it is the wrong default for a background CPU-only continued-processing grant.

Remaining follow-on work on this tranche:

- add a checked-in entitlements file and provisioning story for any GPU-enabled continued-processing build
- add an explicit proof execution context and wire it from scheduler outcome to prover behavior
- refactor the GPU path into checkpointable epochs instead of a single blocking Metal dispatch
- benchmark foreground, continued-processing CPU, and optional continued-processing GPU behavior on supported devices before shipping the GPU path

Benchmark requirements:

- iPhone proof latency by device class
- payload sizes before and after compression
- battery and thermal observations where available

Do not continue until:

- the proof subsystem can be benchmarked independently of the rest of the wallet
- the proof contract can fail cleanly without corrupting draft state
- a long-running proof can be suspended or expired without losing the sealed send capsule

## Step 10: Post-Quantum Address Resolution

Primary files:

- `Numi Wallet/Models/WalletModels.swift`
- `Numi Wallet/Core/RootWalletVault.swift`
- discovery or new resolution clients
- new storage modules

Execution order:

1. add a model for short identifier to large document resolution
2. add local cache records with document digest and freshness state
3. add private resolution requests through the configured service topology
4. add send-flow branching:
   - cached valid document
   - live resolution needed
   - resolution failed
   - resolution disputed
5. add rotation and revocation handling for contact documents

On iOS specifically:

- keep only compact previews and digests in UI-facing state
- keep full resolved documents in a `Contact Document Vault`
- never keep full large identity documents resident in SwiftUI view models longer than necessary

Do not continue until:

- contacts can be resolved privately from short identifiers
- resolution freshness and dispute state are visible to the wallet core

## Step 11: Governance And Nullifier Proofs

Primary files:

- new governance modules
- `Numi Wallet/Core/LocalProver.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- `Numi Wallet/App/WalletAppModel.swift`

Execution order:

1. define governance checkpoint state
2. define proof input material requirements
3. build proof job contracts for governance separately from spend proofs
4. build vote intent and review flow
5. build receipt and verification flow

Do not reuse spend-proof code blindly. Governance has a different threat model and different user expectations.

Required state:

- governance checkpoint height
- eligible note references
- nullifier non-membership proof inputs or equivalent protocol inputs
- vote intent draft
- vote receipt

Add tests for:

- vote with valid checkpoint
- vote after checkpoint expiry
- proof generation failure
- same note becoming ineligible after spend

On iOS specifically:

- governance proof work should reuse the same proof capsule and continued-processing infrastructure where possible
- vote review and vote approval should be clearly distinct from spend approval

Do not continue until:

- governance proofs are modeled as first-class wallet work, not as an afterthought piggybacking on spend UI

## Step 12: Pool Migration

Primary files:

- `Numi Wallet/Core/RootWalletVault.swift`
- new migration modules
- dashboard and orchestration surfaces

Execution order:

1. build inventory of notes across legacy and Tachyon pools
2. define migration eligibility and blockers
3. add migration planner
4. add partially completed migration recovery
5. add post-migration verification and balance reconciliation

The product rule here is simple:

- migration cannot be a hidden background trick
- migration must be inspectable, resumable, and failure-aware

Do not continue until:

- the wallet can explain what has migrated, what remains, and what is blocked

## Step 13: Audit, Benchmarks, And Failure Drills

This is not optional cleanup. It is part of implementation.

Deliverables:

- threat model
- protocol integration notes
- backend contract notes
- benchmark reports
- chaos and failure drill results

Mandatory drills:

- one PIR provider lies
- all PIR providers unavailable
- ratchet state replay attempt
- fee quote expires mid-send
- continued-processing proof expires mid-job
- governance checkpoint stale
- migration interrupted halfway through

## App Attest Bootstrap Work

This deserves its own section because the current repo is not finished here.

Current repo gap:

- `AppAttestProvider` generates keys and assertions
- it does not yet model the full Apple attestation bootstrap and server-validation lifecycle

Required iOS flow:

1. generate a device-local App Attest key ID
2. send an attestation challenge from the server
3. call `attestKey`
4. have the server verify and register the attested key
5. only after successful registration treat assertions from that key as normal
6. for critical requests, generate assertions over client data that includes replay-resistant server input

Numi design:

- `Attestation Session`
  - a short-lived server-issued replay context for multiple requests
- `Assertion Receipt`
  - local record of which attested key and which replay context was used

Uncertainty:

- the exact server challenge bundling strategy for background-friendly requests needs more backend design work
- the current code path that signs only the request body is not enough to claim full replay resistance by itself

## Suggested File Additions

These are likely additions needed to keep the work coherent:

- `Numi Wallet/Models/TachyonModels.swift`
- `Numi Wallet/Core/TachyonStateAdapter.swift`
- `Numi Wallet/Core/TachyonDiscoveryAdapter.swift`
- `Numi Wallet/Core/TachyonTransactionAdapter.swift`
- `Numi Wallet/Core/TachyonProofAdapter.swift`
- `Numi Wallet/Networking/PIRProviderRegistry.swift`
- `Numi Wallet/Networking/AddressResolutionClient.swift`
- `Numi Wallet/Core/GovernanceCoordinator.swift`
- `Numi Wallet/Core/MigrationPlanner.swift`
- `Numi Wallet/Core/PIRReadinessLedger.swift`
- `Numi Wallet/Core/SendCapsuleStore.swift`

## Task Template For AI Developers

Every implementation task in this program should be written using this template:

1. Goal
2. Dependency gate
3. Files to touch
4. State model changes
5. Runtime behavior changes
6. Failure cases
7. Tests to add
8. Definition of done

If a task cannot fill in those eight fields, it is not ready to implement.

## Anti-Patterns To Avoid

1. Do not hard-code Tachyon behavior directly into `WalletAppModel` or SwiftUI views.
2. Do not make remote PIR or relay services implicit trust anchors.
3. Do not store relationship and contact state in one undifferentiated blob.
4. Do not hide quote expiry, dispute state, or degraded mode behind generic "network error" copy.
5. Do not introduce one giant transaction type that mixes draft state, proof state, relay state, and settlement state.
6. Do not couple foreground proofing and continued-processing proofing to different proof job shapes.
7. Do not claim "instant spend" unless witness freshness and nullifier confidence are actually sufficient.
8. Do not load long-lived descriptor secrets in background refresh paths if refresh tickets suffice.
9. Do not assume App Attest is complete until the server-verified attestation bootstrap exists.

## Stop Conditions

Pause and re-evaluate the execution plan if any of these become true:

- Tachyon public specs invalidate a core adapter assumption
- PIR service contracts stop being deterministic enough for comparison mode
- transaction or proof structure changes eliminate the current bundle/action/stamp boundary
- large-address resolution semantics become incompatible with the current contact model
- governance requires new trust assumptions that violate Numi's doctrine
- iOS background scheduling or entitlement constraints make the continued-processing proof lane non-viable for real users

## Sources

- Tachyon overview: <https://tachyon.z.cash/>
- Tachyon roadmap: <https://tachyon.z.cash/roadmap/>
- Tachyon repository: <https://github.com/tachyon-zcash/tachyon>
- Ragu Book: <https://tachyon.z.cash/ragu/print.html>
