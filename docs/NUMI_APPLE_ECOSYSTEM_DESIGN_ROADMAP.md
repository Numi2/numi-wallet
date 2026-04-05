# Numi Apple Ecosystem Design Roadmap

Last updated: April 5, 2026

## Purpose

This document turns Numi's architecture into a cross-device product design plan for iPhone, Apple Watch, iPad, and Mac. It defines the role of each device, the surfaces we should build, the surfaces we should refuse to build, and the order in which the ecosystem should ship.

See also:

- [Numi Future Of Crypto Roadmap](NUMI_FUTURE_OF_CRYPTO_ROADMAP.md)
- [Numi Tachyon Execution Guide](NUMI_TACHYON_EXECUTION_GUIDE.md)
- [Numi Architecture And Roadmap](NUMI_ARCHITECTURE_AND_ROADMAP.md)
- [Numi State Of The Art Apple Plan](NUMI_STATE_OF_THE_ART_APPLE_PLAN.md)

## North Star

Numi should feel like a sovereign instrument built natively for Apple hardware, not a crypto dashboard ported into SwiftUI.

- iPhone is the authority device and the emotional center of the product.
- Apple Watch is a wrist sentinel, not a mini wallet.
- iPad is the clearest recovery and co-presence peer.
- Mac is the proof lane, audit console, and power peer.
- Glass, blur, depth, motion, and haptics should clarify trust state and hierarchy, never decorate speculation.
- Privacy wins over ambient convenience whenever the two conflict.

## Product Position

Numi should express three ideas across the ecosystem:

1. This wallet belongs to the user, not to a cloud account.
2. Trust is physical, local, and visible.
3. Sensitive value appears only when policy is satisfied.

The product should stay quiet by default. That means no balance-forward home screen surfaces, no reusable public identity metaphors, and no system integrations that casually leak financial state.

Numi should also be selective about what it supports. The wallet is only for privacy-focused, post-quantum-safe or post-quantum-forward crypto systems that can be made compatible with Numi's sovereignty doctrine. If a coin fundamentally depends on transparent graph exposure, reusable identity, or architecture that cannot be reconciled with device-local trust and metadata resistance, it should not be integrated.

## Ecosystem Doctrine

- iPhone remains the sole authority surface.
- Cross-device features must strengthen local trust, not dilute it.
- Apple ecosystem breadth is used to deepen sovereignty, not to broaden casual access.
- Privacy features must remove waiting, scanning, and metadata leakage from the user's experience.
- Post-quantum safety should guide long-lived key and signing choices everywhere Apple provides a credible path.
- Coin-specific protocol features should appear as capabilities, not as universal assumptions forced onto every supported rail.

This last point matters for product design as much as protocol engineering. Some future coins may support PIR state refresh, tag ratchets, blinded discovery, or dynamic fee markets. Others may not. The Apple experience should stay coherent in both cases: inactive capabilities should read as intentionally unsupported for the selected coin, not as app breakage.

## Platform Role Map

| Platform | Role | What it should do well | What it must never become |
| --- | --- | --- | --- |
| iPhone | Authority wallet | Setup, receive, spend, vault access, recovery orchestration, peer management | A dense trading dashboard or a generic crypto control panel |
| Apple Watch | Wrist sentinel | Neutral alerts, local presence handoff, session sealing, discreet trust-state awareness | A standalone wallet, a balance screen, or a recovery peer |
| iPad | Recovery and presence peer | Hold fragment, confirm presence, approve re-enrollment, guide recovery drills | A second daily-spend wallet |
| Mac | Proof coprocessor and recovery peer | Proof acceleration, peer admin, recovery approval, diagnostics, auditable system state | The authority signer or a remote trust dependency |

## Design Language

### Materials

- Use liquid-glass style materials for chrome, command docks, peer-state trays, and ceremonial transitions.
- Use denser, more opaque materials whenever content is sensitive or demands unambiguous legibility.
- Keep glass structural. If a layer does not improve hierarchy, depth, or focus, it should not be glass.

### Typography

- Use SF Pro across iPhone, iPad, and Mac.
- Use SF Compact on Apple Watch.
- Reserve monospaced text for digests, fingerprints, timestamps, and protocol evidence.
- Favor short, decisive labels over explanatory paragraphs in privileged flows.

### Color

- Base the system on cool neutrals and mineral surfaces, with small high-confidence accents for state.
- Green means safe progression or verified readiness.
- Amber means missing policy or degraded safety.
- Red is reserved for destructive or panic states.
- Avoid colorful finance tropes. Numi should read as infrastructure, not as a market terminal.

### Motion

- Motion should communicate seal, reveal, handoff, verification, and completion.
- Use slow, physically believable transitions for vault and recovery moments.
- Use tighter, faster motion for transit and receive flows.
- Respect Reduce Motion with alternate opacity and scale behavior, not broken layout.

### Haptics And Sound

- Use haptics to confirm trust-state change, not every tap.
- Ship with no ornamental sounds.
- Important haptics should map to four moments only: unlock, verified peer present, sealed, and transfer complete.

## System-Wide Rules

- No sensitive balances in notifications.
- No reusable receive addresses presented as the mental model.
- No Home Screen widgets at launch.
- No Lock Screen widgets at launch.
- No Apple Watch complications or Smart Stack surfaces at launch.
- No Live Activities at launch.
- No Siri or Spotlight indexing of sensitive entities.
- No generic editable secret-bearing text areas in shipping flows.

These are not temporary omissions. They are part of the privacy posture. We should revisit them only if we can prove that the system surface leaks nothing meaningful.

## Current Implementation Direction

The current codebase already reflects several ecosystem-level product decisions that should remain stable:

- The app shell is Apple-native and built around Secure Enclave, Keychain access control, LocalAuthentication, App Attest, and protected-data lifecycle handling.
- Advanced privacy protocol machinery such as PIR refresh, tag-ratchet discovery, relay submission, and dynamic fee authorization is wired into the client, but gated per coin profile.
- The UI is expected to communicate protocol truth. If a coin does not support a privacy capability, the surface should say that capability is inactive for that coin rather than imply it exists.
- Background behavior is part of the privacy design. PIR-enabled coins may use background refresh to preserve immediate-pay readiness; coins without that model should still boot cleanly without pretending to sync.

## iPhone Roadmap

### Product Role

The iPhone app is the canonical Numi experience. It must feel complete on its own while also making the larger device topology obvious.

### Core Surfaces

- First-run ceremony
  - Establish authority.
  - Explain there is no seed phrase and no cloud restore.
  - Move directly into peer enrollment.
- Daily wallet
  - Show day-wallet state with strong hierarchy and minimal cognitive load.
  - Keep vault information absent until unlocked, not merely blurred.
- Transit flow
  - Replace prototype send forms with a guided settlement composer.
  - Make fees, readiness, proof, and peer dependencies explicit.
- Vault chamber
  - Treat vault access as a deliberate state transition with clear preconditions.
  - Show exactly which peer or policy requirement is missing.
- Recovery orchestration
  - Replace plaintext workflows with bounded device-to-device channels.
  - Make every step name the approving device and role.
- Privacy shield
  - Maintain redaction on background, capture, screenshot, and protected-data loss.

### Interaction Rules

- Primary actions should live in a bottom command region for one-handed reach.
- Secret-bearing flows should use full-screen presentations and explicit dismissal.
- Destructive choices should never hide behind swipe gestures alone.
- Large-number presentation should privilege legibility over novelty.

### iPhone Milestones

#### Phase 1: April 2026 to June 2026

- Finish the authority shell and first-run ceremony.
- Build a real private transfer composer.
- Replace the remaining transitional recovery workspace with authenticated local transfer.
- Make Apple trust posture visible in the authority shell and first-run ceremony.
- Establish role-specific app roots and a local trust ledger so peer administration becomes a first-class surface.
- Finalize the core visual system: glass tiers, panel density, spacing, motion, haptics.

#### Phase 2: July 2026 to September 2026

- Ship production receive and spend flows.
- Add peer management, trust records, and clear degraded-state messaging.
- Refine offline, low-power, and protected-data-loss behavior.

## Apple Watch Roadmap

### Product Role

Apple Watch should be a discreet trust companion. It is not a smaller copy of the iPhone app. Its job is to tell the user whether Numi is ready, sealed, or asking for deliberate physical attention.

### Core Surfaces

- Readiness orb
  - One glance tells the user whether Numi is sealed, ready, waiting on a peer, or degraded.
- Neutral event prompts
  - "Action needed on iPhone."
  - "Peer nearby."
  - "Session sealed."
  - "Recovery drill due."
- Local presence handoff
  - Begin or confirm a proximity event that continues on the iPhone.
- Remote seal
  - Let the user seal the current iPhone session from the wrist with an intentionally sparse interaction.

### Interaction Rules

- Every screen must be understandable in under two seconds.
- Text should stay short enough to read at wrist distance.
- Use haptics for state change and risk, not decoration.
- Prefer vertically stacked single-purpose screens over dense lists.

### Explicit Non-Goals

- No balances on the watch.
- No receive codes or addresses.
- No transaction history.
- No note lists, fees, or counterparties.
- No standalone spend approval.
- No recovery-fragment storage.
- No complications, Smart Stack cards, or wallet widgets in 1.0.

### Watch Milestones

#### Phase 3: October 2026 to December 2026

- Ship a dedicated watchOS companion with readiness, seal, and neutral prompt flows.
- Tune haptics and motion for subtle, high-confidence state feedback.
- Add local continuity between watch and iPhone for presence and session management.

## iPad Roadmap

### Product Role

iPad should be the clearest peer device in the ecosystem. It has enough screen area to explain trust and recovery visually without turning into a second authority wallet.

### Core Surfaces

- Peer home
  - Show role, pairing health, last confirmation, and recovery readiness.
- Presence approval
  - Confirm co-presence for vault or recovery flows.
- Fragment custody
  - Explain what the device holds and what it does not hold.
- Re-enrollment approval
  - Approve or reject authority-device replacement.
- Recovery drill mode
  - Walk the user through a dry run with large, explicit steps.

### Interaction Rules

- Use split layouts to separate explanation from action.
- Treat iPad as the best teaching surface for trust topology.
- Keep secret-bearing material behind explicit reveals with strong local-auth gating.

### iPad Milestones

#### Phase 2: July 2026 to September 2026

- Ship a role-specific peer app.
- Build presence approval and re-enrollment flows.
- Build a real recovery drill experience with strong error recovery and clear language.

## Mac Roadmap

### Product Role

Mac should feel like a restrained coprocessor and peer workstation. It is where advanced users understand proof jobs, pair status, and recovery readiness without ever confusing the device for the authority signer.

### Core Surfaces

- Proof lane
  - Show local proving work, job status, and bounded progress.
- Peer administration
  - Pair, inspect, rotate, and revoke trust records.
- Recovery approval
  - Handle fragment custody and authority-device replacement approval.
- Diagnostics
  - Provide attestation status, local session health, and audit-friendly event views.

### Interaction Rules

- Favor calm two-column layouts over dashboard sprawl.
- Show more evidence than on iPhone, but not more secrets.
- Make every advanced action explain whether it affects trust, performance, or recovery.

### Mac Milestones

#### Phase 2: July 2026 to September 2026

- Ship role-specific Mac peer flows.
- Introduce proof-offload UX tied to explicit authority confirmation on iPhone.
- Add diagnostics views useful for support, review, and security testing.

## Cross-Device Experience Roadmap

### Pairing

- Pairing should feel ceremonial but quick.
- The user should always know which device is leading and which device is joining.
- Visual language should reinforce local trust: proximity, transcript confirmation, explicit role assignment.

### Handoff

- Handoff should move intent, not secrets.
- Watch to iPhone should be a prompt and context transfer.
- iPhone to iPad or Mac should be an attested local-session continuation.

### Notifications

- The default notification voice should be neutral and non-financial.
- Messages should describe action state, not wallet contents.
- The user should be able to disable all nonessential notifications without losing safety.

### Accessibility

- VoiceOver must describe trust state, not just visible labels.
- Dynamic Type must preserve the hierarchy of amount, state, and action.
- Reduced transparency and increased contrast should preserve the visual language, not collapse it.
- Watch, iPhone, iPad, and Mac should all share the same state vocabulary so accessibility language is consistent.

## Phased Product Plan

### Milestone A: Authority iPhone

Target window: April 2026 to June 2026

- Complete the iPhone design language.
- Replace prototype send and recovery surfaces.
- Make first-run worthy of the product's trust claims.
- Lock the system-wide privacy rules.

### Milestone B: Peer Devices

Target window: July 2026 to September 2026

- Ship dedicated iPad and Mac peer experiences.
- Turn recovery, presence, and re-enrollment into real multi-device journeys.
- Give Mac a clear proof-lane identity.

### Milestone C: Wrist Companion

Target window: October 2026 to December 2026

- Ship the Apple Watch companion.
- Add seal, readiness, and neutral prompts.
- Verify that the watch experience improves trust awareness without becoming an ambient leak.

### Milestone D: Launch Hardening

Target window: January 2027 to March 2027

- Run a full accessibility pass across all platforms.
- Finalize motion, haptics, copy, localization, and degraded-state behavior.
- Complete App Store design assets and reviewer-safe explanations.
- Align launch materials with the actual trust model, not crypto-industry conventions.

## Definition Of Done

The ecosystem design is ready for 1.0 when all of the following are true:

- Every device has one obvious job.
- The iPhone feels complete without making the peer devices optional in recovery.
- Apple Watch improves confidence without leaking sensitive state.
- iPad and Mac feel role-specific, not like stretched copies of the phone app.
- Every privileged flow names the approving device and reason.
- No system surface accidentally reveals balances, counterparties, or reusable identifiers.
- Accessibility, reduced-motion behavior, and privacy behavior hold across the full device set.

## Apple Guidance To Stay Aligned With

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)
- [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)
- [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
