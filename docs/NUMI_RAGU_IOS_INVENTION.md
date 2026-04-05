# Numi Ragu iOS Invention

Last updated: April 5, 2026

## Why this exists

Numi needs an iPhone-native proof contract for Tachyon before Zcash locks the final wallet wire format.

The public Tachyon material is already firm enough on a few points:

- the payment layer is being decoupled from the shielded protocol and PIR is a first-class delivery path
- Ragu is the foundational proof-carrying-data system for Tachyon
- Tachyon transactions already separate bundle, action, and stamp
- the public Tachyon repository still marks proof creation, merge, verification, and stamp compression as pending deeper Ragu and Poseidon integration

That means the right immediate move for Numi is not pretending the final proof backend is done. The right move is to make the iOS shell proof-ready now with the correct boundaries.

## Source-backed decisions

### 1. Keep recursive work uncompressed on device

The Ragu Book states that recursion naturally operates in uncompressed mode and that compression should happen only at transmission or storage boundaries.

Numi implication:

- `TachyonProofJob` carries both a compression mode and a compression boundary
- the send pipeline defaults to `.compressed` at the relay boundary
- the wallet-state check keeps the proof lane in `.uncompressed`

### 2. Treat Ragu as a local backend, not a trust anchor

The Ragu Book documents `no_std` compatibility for the library crates, while Tachyon’s roadmap still frames Ragu as under active construction and optimization.

Numi implication:

- the iPhone owns proof-job construction, proof verification, and spend authorization
- the proof backend can change later without changing the SwiftUI shell
- current code uses a deterministic local fallback engine behind the Ragu-shaped contract until upstream proof APIs stabilize

### 3. Mirror Tachyon’s bundle/action/stamp split inside the wallet

The public Tachyon repository says tachygrams live in the stamp rather than in the action so proof aggregation can strip stamps while retaining authorizations.

Numi implication:

- `TachyonBundleDraft`
- `TachyonActionDraft`
- `TachyonStampDraft`
- `TachyonSendCapsule`
- `TachyonSubmissionEnvelope`

These types now exist in Swift so the app shell no longer needs to infer Tachyon structure from generic spend objects alone.

### 4. Bind proof jobs to wallet state, witness state, and fee state explicitly

The current public Tachyon direction and Sean Bowe’s Tachyon writing both point to out-of-band payments, oblivious synchronization, and proof aggregation as the real pressure points on wallet architecture.

Numi implication:

- every `TachyonProofJob` carries:
  - wallet-state digest
  - transaction-draft digest
  - witness digest
  - optional quote-binding digest
  - transcript digest
  - expiry
- every returned `TachyonProofArtifact` is re-verified locally against those digests before use

## What landed in code

- `Numi Wallet/Models/TachyonModels.swift`
- `Numi Wallet/Core/TachyonStateAdapter.swift`
- `Numi Wallet/Core/TachyonDiscoveryAdapter.swift`
- `Numi Wallet/Core/TachyonTransactionAdapter.swift`
- `Numi Wallet/Core/TachyonProofAdapter.swift`
- `Numi Wallet/Core/TachyonSupport.swift`

Operationally:

- `LocalProver` now speaks a Tachyon/Ragu-shaped proof job contract
- `RootWalletVault.submitSpend` now builds a `TachyonSendCapsule`, creates a proof job, verifies the resulting artifact locally, and only then attaches Tachyon proof metadata to relay submission
- `RootWalletVault.runProof` now uses the same proof contract instead of the old ad-hoc witness digest path

## Current limitation

This is not a real upstream Ragu proving backend yet.

It is the iOS-side invention layer that Numi needed first:

- stable Swift models
- stable adapter seams
- stable verification order
- stable relay-boundary compression semantics

When Tachyon and Ragu publish a concrete wallet-facing proving API, that backend can drop behind the current contract without forcing another shell-level rewrite.

## Sources

- Ragu Book: <https://tachyon.z.cash/ragu/print.html>
- Tachyon roadmap: <https://tachyon.z.cash/roadmap/>
- Tachyon repository: <https://github.com/tachyon-zcash/tachyon>
- Sean Bowe, “Tachyaction at a Distance”: <https://seanbowe.com/blog/tachyaction-at-a-distance/>
- Sean Bowe, “Ragu for Orchard: Recursion Al Dente”: <https://seanbowe.com/blog/ragu-for-orchard-part1/>
