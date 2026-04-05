# Numi Tachyon Execution Guide

Last updated: April 5, 2026

See also:

- [Numi Future Of Crypto Roadmap](NUMI_FUTURE_OF_CRYPTO_ROADMAP.md)
- [Numi Architecture And Roadmap](NUMI_ARCHITECTURE_AND_ROADMAP.md)
- [Numi State Of The Art Apple Plan](NUMI_STATE_OF_THE_ART_APPLE_PLAN.md)

## Purpose

This guide is the execution companion to the future-of-crypto roadmap.

It is written so an AI developer or a new engineer can move the Tachyon-readiness program forward without having to infer:

- what comes first
- what must remain configurable
- where the hard technical boundaries are
- what state must exist before the next subsystem is started
- how to know a workstream is complete enough to unblock the next one

This is not a protocol spec for Tachyon. It is Numi's implementation plan for becoming Tachyon-ready while the protocol is still evolving.

## How To Use This Guide

1. Start from the dependency order in this document, not from whichever subsystem looks most interesting.
2. Treat every protocol assumption that is not pinned by a test vector, public spec, or manifest version as configurable.
3. Do not couple the SwiftUI shell to Tachyon internals. Keep Tachyon-specific logic behind adapter and capability boundaries.
4. When a step says "do not continue until", stop there. Those are real dependency gates.
5. For every technically difficult subsystem, implement the state model and test harness before implementing the product surface.

## Non-Negotiable Invariants

These invariants should be enforced throughout the execution plan:

1. The authority key remains on the authority iPhone.
2. Remote services are helpers, never trust anchors.
3. Protocol capabilities must be explicit in manifests and runtime state.
4. "No sync" cannot mean "blind trust in a server." It means private refresh with bounded verification strategy.
5. Relationship discovery state must be recoverable enough for normal wallet life, but must not collapse into a reusable address model.
6. Proof acceleration on Mac is optional. Proof correctness verification on iPhone is mandatory.
7. Post-quantum migration must not be bolted on later. Data models introduced now must leave room for large identities and new key structure.

## Dependency Order

Do the work in this order:

1. Capability model and manifest topology
2. Tachyon adapter boundary
3. PIR subsystem v2
4. Relationship and ratchet state machine
5. Shadow receive and note-ingestion pipeline
6. Fee privacy subsystem
7. Transaction builder and proof job contracts
8. Real proof integration
9. Post-quantum address resolution
10. Governance and nullifier-proof lane
11. Pool migration product flow
12. Audit, benchmarks, and failure drills

This order matters.

Examples:

- Do not implement real Tachyon proving before the adapter boundary exists.
- Do not build shadow receive before the PIR and ratchet state models are stable.
- Do not build governance UI before governance checkpoint and proof input models exist.

## Repo Baseline

The current codebase already gives the execution plan several useful anchors:

- `CoinProtocolCapabilities` and `RemoteServiceConfiguration` already gate protocol features.
- `PIRClient` and `ShieldedStateCoordinator` already model private state refresh.
- `TagRatchetEngine` and `RatchetSecretStore` already model relationship state at a primitive level.
- `DynamicFeeEngine` already has a placeholder bundle model for quote, commitment, hotkey, and settlement.
- `RootWalletVault` already contains the dominant authority-wallet orchestration boundary.
- `LocalProver` exists as the future proving seam.

That means the right next move is not "start proving." The right next move is "stabilize the adapter and capability surface so everything else can land cleanly."

## Step 0: Establish The Tachyon Lab

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

## Step 1: Capability Model And Manifest Topology

This is the first code change that should land.

Primary files:

- `Numi Wallet/Models/WalletModels.swift`
- `Numi Wallet/Models/CoinManifestModels.swift`
- `Numi Wallet/Core/CoinManifestLoader.swift`
- `Numi Wallet/NumiCoinManifest.json`
- `docs/manifests/`

Current problem:

- `CoinProtocolCapabilities` is too small and boolean-only.
- Tachyon needs more than yes/no toggles. It needs feature families and service topology that can evolve without breaking the app shell.

Implement in this order:

1. Introduce named capability groups.
   - State refresh
   - discovery
   - fee privacy
   - relay submission
   - address resolution
   - governance
   - migration
2. For each group, add a mode or version field rather than only a boolean.
3. Keep a compatibility layer so the current preview manifest still loads.
4. Add service topology for distinct PIR classes instead of a single PIR bucket if needed by the runtime.
5. Add manifest validation rules that reject impossible combinations.

Examples of invalid combinations:

- tag-based discovery enabled without a tag-capable PIR route
- hidden-fee settlement enabled without fee quote and relay settlement topology
- governance enabled without a checkpoint or proof-input source

Add acceptance checks:

- the manifest loader rejects invalid topology with explicit errors
- the dashboard can render inactive, partial, and active capability states
- the app can load a Tachyon profile without hard-coding Tachyon behavior into the shell

Do not continue until:

- the manifest can represent Tachyon without abuse of placeholder booleans
- runtime code can branch on capability mode instead of ad hoc string checks

## Step 2: Define The Tachyon Adapter Boundary

This is the most important architectural decision in the whole program.

Primary files:

- `Numi Wallet/Core/RootWalletVault.swift`
- `Numi Wallet/Core/LocalProver.swift`
- `Numi Wallet/Models/ShieldedProtocolModels.swift`
- new Tachyon-specific modules under `Numi Wallet/Core/` and `Numi Wallet/Models/`

Current problem:

- `RootWalletVault` orchestrates shielded work, but there is no protocol adapter boundary that isolates Tachyon transaction semantics from the app shell.

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
- peer and Mac job orchestration
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

## Step 3: PIR Subsystem V2

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

### Data Model Changes

Add explicit models for:

- PIR provider identity
- per-query-class provider policy
- query receipt
- signed response metadata
- mismatch event
- dispute evidence snapshot
- anchor-root freshness state

Suggested additions:

- `PIRProvider`
- `PIRQueryPolicy`
- `PIRQueryReceipt`
- `PIRMismatchRecord`
- `PIRDisputeEvidence`
- `ShieldedAnchorState`

### Execution Order

1. Split `PIRClient` responsibilities.
   - transport
   - request encoding
   - response verification
   - provider selection
2. Add a provider registry in runtime configuration.
3. Introduce per-query-class policies.
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

Do not continue until:

- refresh results are persisted with provider and chain-state context
- the app can distinguish stale from disputed
- immediate-spend posture is blocked when verification confidence is insufficient

## Step 4: Relationship And Ratchet State Machine

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

Do not conflate:

- contact identity
- receive descriptor
- ratchet material

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

## Step 5: Shadow Receive And Note Ingestion

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

Do not continue until:

- shadow receive can ingest fixture notes end to end
- discovered notes and spendable notes are clearly separated in state and UI

## Step 6: Fee Privacy And Hotkey Settlement

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

### Required Data Boundaries

Keep these objects separate:

- `FeeIntent`
- `FeeMarketQuote`
- `HiddenFeeCommitment`
- `FeeHotkeyGrant`
- `FeeSettlementResult`

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

## Step 7: Transaction Builder And Proof Job Contracts

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
4. outgoing discovery/tag material
5. fee intent and quote
6. transaction draft assembly
7. proof job creation
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

Keep these internal models decoupled from the final on-wire encoding if possible.

### Mac Offload Contract

Define the proof offload contract before implementing transport:

- job ID
- wallet state digest
- transaction draft digest
- witness fragment digest
- expiry
- transcript digest
- returned proof artifact digest

The Mac may:

- compute proofs
- compress proofs
- return benchmark metrics

The Mac may not:

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

- local and Mac proof jobs share the same contract
- the iPhone remains the final verifier before spend authorization

## Step 8: Real Proof Integration

Only begin this after Steps 2 through 7 are complete.

Primary files:

- `Numi Wallet/Core/LocalProver.swift`
- Tachyon proof adapter modules
- Mac proof-offload modules

Execution order:

1. land a mock proof backend that obeys the real proof job contract
2. land a benchmarkable local proof runner
3. land Mac offload using the same contract
4. only then switch one pathway to the real proving backend

This staged approach matters because otherwise the team will blur:

- transport failures
- proof failures
- job-shape failures
- UI failures

Benchmark requirements:

- iPhone proof latency by device class
- Mac proof latency by device class
- payload sizes before and after compression
- battery and thermal observations where available

Do not continue until:

- the proof subsystem can be benchmarked independently of the rest of the wallet
- the proof contract can fail cleanly without corrupting draft state

## Step 9: Post-Quantum Address Resolution

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

Hard rules:

- never teach the user that a large document is "their address"
- never silently use a stale cached document when the policy requires fresh resolution
- keep resolution evidence if providers disagree

Do not continue until:

- contacts can be resolved privately from short identifiers
- resolution freshness and dispute state are visible to the wallet core

## Step 10: Governance And Nullifier Proofs

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

Do not continue until:

- governance proofs are modeled as first-class wallet work, not as an afterthought piggybacking on spend UI

## Step 11: Pool Migration

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

## Step 12: Audit, Benchmarks, And Failure Drills

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
- proof offload returns mismatched artifact
- governance checkpoint stale
- migration interrupted halfway through

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
6. Do not couple the Mac proof-offload path to a different proof job shape than the iPhone local path.
7. Do not claim "instant spend" unless witness freshness and nullifier confidence are actually sufficient.

## Stop Conditions

Pause and re-evaluate the execution plan if any of these become true:

- Tachyon public specs invalidate a core adapter assumption
- PIR service contracts stop being deterministic enough for comparison mode
- transaction or proof structure changes eliminate the current bundle/action/stamp boundary
- large-address resolution semantics become incompatible with the current contact model
- governance requires new trust assumptions that violate Numi's doctrine

## Sources

- Tachyon overview: <https://tachyon.z.cash/>
- Tachyon roadmap: <https://tachyon.z.cash/roadmap/>
- Tachyon repository: <https://github.com/tachyon-zcash/tachyon>
- Ragu Book: <https://tachyon.z.cash/ragu/print.html>
