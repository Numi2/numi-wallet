# Numi Future Of Crypto Roadmap

Last updated: April 5, 2026

See also:

- [Numi Tachyon Execution Guide](NUMI_TACHYON_EXECUTION_GUIDE.md)
- [Numi Architecture And Roadmap](NUMI_ARCHITECTURE_AND_ROADMAP.md)
- [Numi State Of The Art Apple Plan](NUMI_STATE_OF_THE_ART_APPLE_PLAN.md)
- [Numi Apple Ecosystem Design Roadmap](NUMI_APPLE_ECOSYSTEM_DESIGN_ROADMAP.md)

## Purpose

This document turns Numi's doctrine into a concrete strategy for the next generation of privacy-preserving crypto systems.

For step-by-step implementation sequencing and deeper technical guidance, use [Numi Tachyon Execution Guide](NUMI_TACHYON_EXECUTION_GUIDE.md) alongside this roadmap. For the current shipping milestone, that execution guide is the authoritative iOS-only implementation path.

Current shipping restriction for this program:

- Numi's Tachyon milestone is iOS only
- macOS, watchOS, and visionOS are out of scope for the current Tachyon-ready definition
- all proof correctness, authority, and readiness claims must stand on the iPhone alone

The immediate forcing function is Project Tachyon for Zcash. Tachyon is the clearest public example of where serious privacy wallets are going next:

- no full-chain shielded sync on the phone
- PIR-backed state refresh and payment discovery
- recursive proof systems and proof aggregation
- hidden metadata for fees and delivery
- simplified key structure and post-quantum migration pressure
- wallet participation in governance without sacrificing privacy

Numi should treat Tachyon as the first major compatibility target, not the only one. The product should become the sovereign Apple wallet shell that can adapt to this class of protocol without rebuilding its identity every time a coin evolves.

## Planning Baseline

The current planning baseline is a mix of public Tachyon material and user-supplied developer notes.

Public Tachyon signals:

- Tachyon's public overview positions it as a Zcash scalability upgrade that shrinks transaction footprint, removes runaway validator state growth, and obtains full post-quantum privacy as a side effect.
- Tachyon's public roadmap says the payment layer is being decoupled from the shielded protocol, and one delivery approach uses Private Information Retrieval and post-quantum key exchange with minimal UX change.
- The same roadmap says Tachyon is designing a new shielded pool with a simplified key structure intended to support the parallel payment layer.
- The public repository shows an action/stamp split where nullifiers and note commitments live in the stamp rather than in the action, which is specifically meant to support proof aggregation.
- The repository also shows that note commitments, nullifier derivation, proof creation, merge, verification, and stamp compression are still pending deeper Ragu and Poseidon integration.
- The Ragu documentation shows the proof system is explicitly being shaped around recursive proof-carrying data, Pasta curves, and heavy use of Poseidon for transcript and circuit efficiency.

Developer-note assumptions that Numi should actively plan for:

- PIR replaces shielded sync for Merkle path refresh and nullifier spent-status checks.
- Payment discovery moves to shared-secret ratchets and private tag lookup.
- Dynamic fee markets hide the user's maximum fee and use short-lived hotkeys for settlement.
- Post-quantum addresses become large documents, with private resolution from short identifiers.
- Governance depends on fast Poseidon-based proofs and privacy-preserving nullifier non-membership checks.

These assumptions should be treated as planning targets, not protocol law. Numi should build the right abstraction boundaries now and keep the concrete adapter behavior flexible until Tachyon ZIPs, testnets, and wallet specs stabilize.

Apple platform baseline for this plan:

- the installed Xcode 26.4 / iPhoneOS 26.4 SDK exposes `SecureEnclave.MLDSA87`, `MLDSA87`, `XWingMLKEM768X25519`, and the HPKE XWing ciphersuite, so the PQ cryptography line is real on the local toolchain
- the same SDK exposes `BGContinuedProcessingTaskRequest`, which creates a credible iPhone-only path for long proof jobs; background GPU remains optional, entitlement-gated, and device-dependent
- `LocalAuthenticationView` is still absent from the local iPhoneOS 26.4 SDK, so the product should stay on `LAContext`, Keychain access control, and system sheets

## Strategic Position

Numi's future-of-crypto position should be explicit:

1. Numi is not trying to be a universal wallet. It is the best possible wallet for privacy-preserving, sovereign, post-quantum-safe systems.
2. Tachyon is the first proof that this product thesis is real. If Numi cannot adapt to Tachyon cleanly, the shell is not future-ready.
3. The app shell should stay stable while protocol machinery is introduced through signed manifests, capability flags, service topology, and adapter boundaries.
4. New privacy features only matter if they improve the user experience in addition to improving the protocol. "Open and pay immediately" is the standard, not "sync and wait."
5. Numi must be testnet-ready before Tachyon is socially final so the wallet team can shape the UX while protocol assumptions are still negotiable.
6. The current Tachyon-ready milestone must not depend on a Mac proof lane or any other non-iOS companion surface.

## North Star

Numi should become the Apple-native wallet operating surface for encrypted money at scale.

That means:

- wake and pay without a local chain scan when the protocol permits it
- discover payments without teaching reusable public address habits
- preserve fee privacy without forcing the user to manually game fee markets
- resolve large post-quantum identities without exposing counterparties to infrastructure
- support migration, governance, and recovery without breaking sovereignty
- keep the authority root and the authoritative proof-verification path on the iPhone even as proving and transport systems evolve

## Product Rules For Next-Generation Coins

Any coin or shielded pool Numi supports in the future should be evaluated against these rules:

1. Wallet readiness must be private by default. No always-on graph exposure, no reusable receive identity, no mandatory cloud account.
2. Protocol truth must be represented explicitly in manifests and UI. If a capability is absent, the app should say so.
3. Remote services may help with delivery, PIR, fee discovery, or address resolution, but they must not become trust anchors.
4. State refresh should be verifiable across providers wherever deterministic responses make that possible.
5. Post-quantum migration cannot be treated as future cleanup. Long-lived wallet design must assume it now.
6. Governance participation should not require moving funds into an exposed, convenience-first mode.

## Required Wallet Capabilities

### 1. Verifiable No-Sync State

Numi must support private state refresh without local blockchain replay.

Required outcomes:

- private Merkle path retrieval
- private nullifier spent-status checks
- private tag lookup for payment discovery
- block-height-aware freshness tracking
- clear UI states for ready, stale, degraded, and disputed data

### 2. Multi-Provider PIR Trust Minimization

Numi should assume PIR services can fail, lie, or go offline.

Required outcomes:

- provider quorum or comparison mode for deterministic queries
- signed response support when available
- mismatch evidence capture for later dispute or slashing systems
- local policy for single-provider degraded mode

### 3. Relationship-Based Discovery

Numi must treat payment discovery as relationship state, not chain scanning.

Required outcomes:

- first-contact introduction flow
- persistent shared-secret ratchets
- lookahead windows for inbound discovery
- clean recovery and rotation story for ratchet state
- clear separation between contact state and descriptor state

### 4. Fee Privacy And Live Settlement

Numi must support hidden-fee models without turning fee selection into a metadata leak.

Required outcomes:

- hidden maximum fee commitment
- short-lived authorized settlement hotkey
- fee quote expiry and refund semantics
- user-facing fee posture without exposing the hidden maximum
- clear failure handling when market conditions move after authorization

### 5. Recursive-Proof-Aware Spend Pipeline

Numi must be able to assemble transactions whose proving story changes over time.

Required outcomes:

- explicit transaction model boundary for bundle, action, stamp, anchor, and proof state
- proof compression and decompression lifecycle support
- local iPhone proof lanes, including continued-processing support where available
- proof verification on the authority device before final spend authorization

### 6. Post-Quantum Identity And Address Resolution

Numi must be ready for the case where a usable address is no longer a short public string.

Required outcomes:

- 32-byte user-facing identifiers where the protocol permits them
- private resolution of large address documents
- contact document storage, rotation, and revocation
- send UX that treats counterparties as rotating descriptors or identity records, not reusable addresses

### 7. Governance Without Spend Exposure

Numi should support governance as a normal wallet function for privacy coins.

Required outcomes:

- checkpointed governance state by block height
- proof of eligible unspent balance without moving funds
- local iPhone proof generation
- vote receipts and verification surfaces

### 8. Pool Migration And Recovery

Numi must make protocol migration survivable.

Required outcomes:

- balance inventory across old and new pools
- guided migration planner
- migration proof and fee estimation
- recovery semantics that survive partially completed migrations

## Current Repository Position

The current repo already contains the right shape for this future, but not yet the full system.

Strong foundations already present:

- capability-gated coin manifests and runtime configuration
- PIR client wiring for Merkle path, nullifier, and tag queries
- shielded state refresh coordination
- shared-secret tag-ratchet bootstrap and persistence
- dynamic-fee scaffolding with quote, commitment, hotkey, and settlement bundle modeling
- signed coin manifest validation
- local proving seam through `LocalProver`
- background PIR refresh hooks for coins that support immediate-pay readiness

Key gaps:

- no explicit iOS-only Tachyon scope lock in build settings or project configuration
- no Tachyon-specific coin adapter or manifest profile
- no multi-provider PIR comparison or signed PIR receipts
- no dispute-evidence or slash-evidence export path
- no checked-in entitlements file for App Attest or continued-processing GPU experiments
- no full App Attest bootstrap and attestation-registration lifecycle
- no production note decryption and witness-building path against Tachyon/Zcash specs
- no real proof backend for recursive shielded spends
- the iPhone continued-processing proof lane exists, but it is still CPU-first and lacks an explicit execution-context split for background CPU versus background GPU grants
- no chunked GPU proof runner that can publish progress and stop cleanly on expiration
- no stamp/action transaction model in the wallet core
- no post-quantum address-resolution client
- no governance proof lane
- no pool migration product flow

## Workstreams

### Workstream 1: Capability Model V2

Goal:

- Move from a small boolean capability set to a future-proof protocol capability model.

Tasks:

- Extend `CoinProtocolCapabilities` to represent named capability families rather than only a handful of booleans.
- Add explicit capability entries for verifiable PIR, signed PIR receipts, hidden-fee settlement, post-quantum address resolution, governance, and pool migration.
- Version capability semantics so Tachyon testnet changes do not force shell-wide breaking changes.
- Add a dedicated `tachyon-testnet` manifest and service topology contract.
- Make degraded mode copy mandatory for every inactive or partially active capability.

Repo touchpoints:

- `Numi Wallet/Models/WalletModels.swift`
- `Numi Wallet/Models/CoinManifestModels.swift`
- `Numi Wallet/Core/CoinManifestLoader.swift`
- `Numi Wallet/NumiCoinManifest.json`

### Workstream 2: PIR State Fabric

Goal:

- Turn PIR from a single-client transport into a verifiable wallet subsystem.

Tasks:

- Split PIR service configuration into query classes: Merkle paths, nullifiers, tags, and future address resolution.
- Add provider lists, comparison policy, and freshness policy.
- Model signed or attestable PIR responses where the server contract supports them.
- Cache responses by block height and anchor root, not only by latest observation time.
- Add mismatch detection, provider scoring, and evidence export.
- Add UI posture states: ready, stale, degraded, disputed.
- Add a `PIR Readiness Lease` and `Refresh Ticket Ledger` so iOS background refresh can maintain readiness without loading long-lived descriptor secrets.

Repo touchpoints:

- `Numi Wallet/Networking/PIRClient.swift`
- `Numi Wallet/Core/ShieldedStateCoordinator.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- `Numi Wallet/App/WalletAppModel.swift`

### Workstream 3: Discovery, Contacts, And Ratchets

Goal:

- Make repeated private payment discovery production-grade.

Tasks:

- Separate first-contact introduction state from established-contact ratchet state.
- Persist lookahead cursor windows and replay protection for incoming tag scans.
- Build contact rotation and relationship reset flows.
- Add recovery/import semantics for relationship state without leaking counterparties into generic exports.
- Make private receive UX contact-oriented and descriptor-oriented, never address-oriented.

Repo touchpoints:

- `Numi Wallet/Core/TagRatchetEngine.swift`
- `Numi Wallet/Security/RatchetSecretStore.swift`
- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/UI/WalletDashboardView.swift`

### Workstream 4: Fee Privacy And Hotkey Settlement

Goal:

- Replace today's placeholder fee commitment path with a protocol-authentic private fee execution model.

Tasks:

- Replace placeholder commitment construction with a proof-backed hidden maximum fee abstraction.
- Bind authorization hotkeys to quote scope, expiry, and settlement digest.
- Separate quote fetch, commitment creation, authorization, relay settlement, and refund reconciliation.
- Add user-visible fee posture that explains confidence and privacy without exposing internal metadata.
- Add failure handling for late quotes, settlement races, and relay rejection.

Repo touchpoints:

- `Numi Wallet/Core/DynamicFeeEngine.swift`
- `Numi Wallet/Networking/FeeOracleClient.swift`
- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`

### Workstream 5: Tachyon Transaction And Proof Pipeline

Goal:

- Give Numi a transaction assembly boundary that can survive Ragu-era proof changes.

Tasks:

- Introduce explicit wallet-side models for bundle, action, stamp, anchor, and proof stages.
- Keep the transaction builder independent from the eventual proving backend so Ragu changes do not infect the app shell.
- Add compression/decompression lifecycle handling for intermediate and transmitted proof objects.
- Define the iPhone proving contract around bounded jobs, transcript digests, local verification on return, and resumable send capsules.
- Add benchmark harnesses for iPhone foreground and continued-processing proof flows.

Repo touchpoints:

- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Core/LocalProver.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- new Tachyon adapter modules under `Numi Wallet/Core/` and `Numi Wallet/Models/`

### Workstream 6: Post-Quantum Address Resolution

Goal:

- Prepare the wallet for large cryptographic identity documents while keeping the UX short and private.

Tasks:

- Introduce a wallet model for short identifiers that resolve to large address documents.
- Add a private resolution client and local cache policy.
- Support identifier rotation, revocation, and contact reconciliation.
- Keep send flows explicit about whether the wallet is using a cached document or live resolution.
- Make address resolution a capability that can be switched on per coin profile.

Repo touchpoints:

- `Numi Wallet/Models/WalletModels.swift`
- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Networking/DiscoveryClient.swift`
- new address-resolution client and storage modules

### Workstream 7: Governance And Nullifier Proofs

Goal:

- Make governance a first-class wallet capability for privacy systems.

Tasks:

- Add governance checkpoint state keyed by block height.
- Model nullifier non-membership or equivalent proof inputs as wallet-managed data.
- Add proof-generation pathways that run locally on iPhone and reuse the same proof capsule contract as spend where appropriate.
- Add voting intent, review, submission, and receipt flows.
- Make governance posture visible without exposing balances or specific note history.

Repo touchpoints:

- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- `Numi Wallet/Core/LocalProver.swift`
- `Numi Wallet/App/WalletAppModel.swift`
- new governance modules and UI surfaces

### Workstream 8: Migration, Testnet Lab, And Audit Readiness

Goal:

- Ensure Numi can survive protocol churn and ship with evidence, not optimism.

Tasks:

- Build a Tachyon lab environment with local manifests, service mocks, and golden vectors.
- Add shadow-mode wallet verification against Tachyon test data before full spend support lands.
- Add migration planning and partially completed migration recovery.
- Define performance budgets for PIR refresh, receive discovery, and proof generation on current iPhone hardware.
- Benchmark the real iPhone proof ladder: foreground, continued-processing CPU, and optional continued-processing GPU on entitled supported devices.
- Ship the GPU continued-processing path only if entitlement provisioning, runtime availability, thermals, and App Review posture are all acceptable. Otherwise keep the continued-processing path CPU-first.
- Produce protocol notes, threat model, test matrix, and backend contract specs for audit.

Repo touchpoints:

- `docs/`
- `docs/manifests/`
- `scripts/`
- new integration-test and benchmark harnesses

## Roadmap

### Phase 1: Protocol Shell Hardening

Status: next

Objectives:

- make Numi capable of describing Tachyon honestly
- lock the current program to an explicit iOS-only path
- formalize the capability surface and service topology
- turn PIR into a verifiable subsystem rather than a single remote client

Tasks:

- lock project and platform configuration to the current iOS-only milestone
- ship capability model v2
- add `tachyon-testnet` manifest and environment wiring
- add PIR provider sets and comparison policy
- add background-safe refresh tickets and readiness leases
- model signed PIR response envelopes and dispute evidence
- define the Tachyon wallet adapter boundary
- design the full App Attest bootstrap and replay-resistant request contract

Exit criteria:

- Numi can load a Tachyon profile, describe inactive pieces honestly, and maintain shadow state without pretending full support exists
- the iOS-only platform configuration story is explicit enough that an AI developer does not have to guess which Apple platforms are in scope

### Phase 2: Shadow Wallet And Receive Readiness

Status: next

Objectives:

- make Numi capable of receiving and tracking Tachyon-style state before full spend support

Tasks:

- implement real relationship-state persistence and replay-safe lookahead
- add contact-aware receive and discovery UX
- add block-height-aware freshness ledger
- add shadow note ingestion against test vectors and mocks
- build dashboard posture for ready, stale, degraded, disputed
- prove that iOS background refresh can maintain honest readiness using refresh tickets rather than long-lived descriptor secrets

Exit criteria:

- Numi can wake, privately refresh, and discover incoming payments in test or shadow environments without chain sync

### Phase 3: Testnet Spend And Proof

Status: later

Objectives:

- deliver real Tachyon send, proof, and submission support

Tasks:

- add Tachyon transaction models
- build note selection and witness construction against real specs
- integrate local iPhone proof generation and continued-processing proof handling where available
- replace fee placeholder logic with protocol-authentic hidden-fee handling
- add relay submission and settlement reconciliation

Exit criteria:

- authority iPhone can send on Tachyon testnet alone without depending on any non-iOS device

### Phase 4: PQ Identity, Governance, And Migration

Status: later

Objectives:

- support the parts of future privacy coins that most wallets will miss

Tasks:

- implement post-quantum address resolution
- implement governance checkpointing and proof flows
- implement migration planning and execution between old and new shielded pools
- add advanced receive and restore behavior for post-quantum identity documents

Exit criteria:

- Numi handles private identity resolution, voting, and protocol migration as part of normal wallet life

### Phase 5: Audit And Launch Readiness

Status: later

Objectives:

- make the product reviewable, measurable, and operationally survivable

Tasks:

- complete threat model and backend contract documentation
- add integration, performance, and chaos testing for PIR provider failure
- add user-facing degraded-mode language across all advanced capabilities
- prepare security review artifacts for the wallet core and remote service contracts

Exit criteria:

- the product is externally reviewable as a sovereign privacy wallet, not just internally coherent

## Immediate Priorities

If Numi executes only the highest-leverage next work, it should be this:

1. Lock the current Tachyon milestone to an explicit iOS-only scope and configuration story.
2. Add capability model v2 and a `tachyon-testnet` manifest.
3. Convert PIR into a provider-aware, verifiable subsystem with refresh tickets and readiness leases.
4. Define the Tachyon transaction and proof adapter boundary before touching proving internals.
5. Build production-grade relationship-state handling for discovery ratchets.
6. Replace the fee-privacy placeholder path with a spec-shaped abstraction that can survive protocol churn.
7. Stand up a Tachyon lab with mocks, vectors, and benchmark scripts.
8. Design the missing App Attest bootstrap and replay-resistant request flow.

## Definition Of Done For Tachyon Readiness

Numi should only claim Tachyon readiness when all of the following are true:

- the wallet can refresh spend readiness privately without chain replay
- payment discovery works through contact state and ratchets, not full-chain scanning
- PIR results can be compared, signed, or otherwise verified according to the service contract
- hidden-fee settlement does not leak the user's effective maximum fee in normal flows
- the authority iPhone verifies proof-bearing spend state locally before signing
- the current Tachyon-ready milestone does not depend on any non-iOS device
- long-running proof work on iPhone either completes through foreground or continued-processing lanes, or degrades honestly without corrupting send state
- post-quantum address resolution, if required by the protocol, is private and recoverable
- governance flows do not force fund movement or reusable public identity
- migration between legacy and Tachyon pools is explicit, reversible where possible, and operationally documented

## Sources

- Tachyon overview: <https://tachyon.z.cash/>
- Tachyon roadmap: <https://tachyon.z.cash/roadmap/>
- Tachyon repository: <https://github.com/tachyon-zcash/tachyon>
- Ragu Book: <https://tachyon.z.cash/ragu/print.html>
