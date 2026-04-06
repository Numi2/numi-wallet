import Foundation

enum WalletFeedbackStyle: String, Sendable {
    case selection
    case success
    case warning
    case error
}

enum WalletExperienceEventKind: String, Sendable {
    case launchReady
    case authorityInitialized
    case dayWalletUnlocked
    case vaultUnlocked
    case vaultSealed
    case descriptorRotated
    case aliasRegistered
    case aliasResolved
    case shieldedStateRefreshed
    case transferSubmitted
    case recoveryPrepared
    case recoveryTransferAwaitingApproval
    case recoveryTransferLoaded
    case recoveryTransferDispatched
    case recoveryTransferRejected
    case recoveryShareImported
    case recoveryShareExported
    case sensitiveWorkspaceScrubbed
    case authorityRecovered
    case panicWipe
    case proofCompleted
    case proofDeferred
    case proofDiscarded
    case privacyShieldRaised
    case peerPresenceEstablished
    case peerPresenceLost
    case failure

    var title: String {
        switch self {
        case .launchReady:
            return "Session Ready"
        case .authorityInitialized:
            return "Authority Established"
        case .dayWalletUnlocked:
            return "Day Wallet Unlocked"
        case .vaultUnlocked:
            return "Vault Chamber Open"
        case .vaultSealed:
            return "Vault Chamber Sealed"
        case .descriptorRotated:
            return "Receive Intent Rotated"
        case .aliasRegistered:
            return "Alias Registered"
        case .aliasResolved:
            return "Alias Resolved"
        case .shieldedStateRefreshed:
            return "Shielded Rail Refreshed"
        case .transferSubmitted:
            return "Private Transfer Submitted"
        case .recoveryPrepared:
            return "Recovery Pair Prepared"
        case .recoveryTransferAwaitingApproval:
            return "Recovery Transfer Waiting"
        case .recoveryTransferLoaded:
            return "Recovery Transfer Loaded"
        case .recoveryTransferDispatched:
            return "Recovery Transfer Sent"
        case .recoveryTransferRejected:
            return "Recovery Transfer Rejected"
        case .recoveryShareImported:
            return "Peer Share Imported"
        case .recoveryShareExported:
            return "Peer Share Exported"
        case .sensitiveWorkspaceScrubbed:
            return "Sensitive Draft Scrubbed"
        case .authorityRecovered:
            return "Authority Re-enrolled"
        case .panicWipe:
            return "Local Unwrap Destroyed"
        case .proofCompleted:
            return "Proof Lane Completed"
        case .proofDeferred:
            return "Proof Capsule Preserved"
        case .proofDiscarded:
            return "Proof Capsule Discarded"
        case .privacyShieldRaised:
            return "Privacy Shield Raised"
        case .peerPresenceEstablished:
            return "Peer Present"
        case .peerPresenceLost:
            return "Peer Lost"
        case .failure:
            return "Action Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .launchReady:
            return "checkmark.circle.fill"
        case .authorityInitialized:
            return "shield.checkered"
        case .dayWalletUnlocked:
            return "sun.max.fill"
        case .vaultUnlocked:
            return "lock.open.fill"
        case .vaultSealed:
            return "lock.fill"
        case .descriptorRotated:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .aliasRegistered:
            return "at.circle.fill"
        case .aliasResolved:
            return "magnifyingglass.circle.fill"
        case .shieldedStateRefreshed:
            return "arrow.clockwise.circle.fill"
        case .transferSubmitted:
            return "paperplane.circle.fill"
        case .recoveryPrepared:
            return "person.2.fill"
        case .recoveryTransferAwaitingApproval:
            return "tray.full.fill"
        case .recoveryTransferLoaded:
            return "tray.and.arrow.down.fill"
        case .recoveryTransferDispatched:
            return "wave.3.left.circle.fill"
        case .recoveryTransferRejected:
            return "tray.and.arrow.up.fill"
        case .recoveryShareImported:
            return "square.and.arrow.down.fill"
        case .recoveryShareExported:
            return "square.and.arrow.up.fill"
        case .sensitiveWorkspaceScrubbed:
            return "eraser.fill"
        case .authorityRecovered:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .panicWipe:
            return "flame.fill"
        case .proofCompleted:
            return "cpu.fill"
        case .proofDeferred:
            return "hourglass.circle.fill"
        case .proofDiscarded:
            return "xmark.circle.fill"
        case .privacyShieldRaised:
            return "eye.slash.fill"
        case .peerPresenceEstablished:
            return "dot.radiowaves.left.and.right"
        case .peerPresenceLost:
            return "wave.3.right"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    var feedbackStyle: WalletFeedbackStyle {
        switch self {
        case .launchReady, .aliasResolved, .descriptorRotated:
            return .selection
        case .authorityInitialized, .dayWalletUnlocked, .vaultUnlocked, .shieldedStateRefreshed, .transferSubmitted,
                .recoveryPrepared, .recoveryTransferLoaded, .recoveryTransferDispatched, .recoveryShareImported, .recoveryShareExported, .authorityRecovered, .proofCompleted,
                .peerPresenceEstablished:
            return .success
        case .recoveryTransferAwaitingApproval:
            return .selection
        case .vaultSealed, .privacyShieldRaised, .peerPresenceLost, .sensitiveWorkspaceScrubbed, .proofDeferred, .proofDiscarded, .recoveryTransferRejected:
            return .warning
        case .panicWipe, .failure:
            return .error
        case .aliasRegistered:
            return .selection
        }
    }
}

struct WalletExperienceEvent: Identifiable, Sendable {
    let id: UUID
    let kind: WalletExperienceEventKind
    let detail: String
    let occurredAt: Date

    init(kind: WalletExperienceEventKind, detail: String, occurredAt: Date = Date()) {
        self.id = UUID()
        self.kind = kind
        self.detail = detail
        self.occurredAt = occurredAt
    }

    var title: String { kind.title }
    var systemImage: String { kind.systemImage }
    var feedbackStyle: WalletFeedbackStyle { kind.feedbackStyle }
}

enum RecoveryWorkspaceTone: String, Sendable {
    case neutral
    case ready
    case caution
    case critical
}

struct RecoveryWorkspaceFact: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: String
}

struct RecoveryWorkspaceSummary: Sendable {
    let title: String
    let subtitle: String
    let recommendation: String
    let systemImage: String
    let tone: RecoveryWorkspaceTone
    let facts: [RecoveryWorkspaceFact]
    let canImportShare: Bool
    let canRecoverAuthority: Bool
}

enum RecoveryWorkspaceInspector {
    static func inspect(stagedTransfer: StagedRecoveryTransfer?) -> RecoveryWorkspaceSummary {
        guard let stagedTransfer else {
            return RecoveryWorkspaceSummary(
                title: "Transfer Lane Idle",
                subtitle: "No signed recovery transfer staged",
                recommendation: "Import a canonical signed Numi transfer document or prepare a new local transfer before attempting recovery actions.",
                systemImage: "tray.fill",
                tone: .neutral,
                facts: [],
                canImportShare: false,
                canRecoverAuthority: false
            )
        }

        let envelope = stagedTransfer.document.envelope
        let documentDigest = hexPrefix(stagedTransfer.document.envelopeDigest)
        let qrChunkCount = "\(stagedTransfer.qrChunks.count)"

        switch envelope.payload {
        case .authorityBundle(let shares):
            let peerNames = shares.map(\.peerName).joined(separator: ", ")
            return RecoveryWorkspaceSummary(
                title: "Signed Authority Recovery Document",
                subtitle: "\(shares.count) fragment(s) for \(envelope.recipientRole.displayName)",
                recommendation: envelope.isExpired
                    ? "This recovery document has expired. Generate a new signed local transfer before attempting authority re-enrollment."
                    : "This canonical Numi transfer document is bounded to authority re-enrollment and can move through file or QR transport without becoming editable recovery JSON.",
                systemImage: "checkmark.shield.fill",
                tone: envelope.isExpired ? .critical : .ready,
                facts: [
                    RecoveryWorkspaceFact(label: "Sender Role", value: envelope.senderRole.displayName),
                    RecoveryWorkspaceFact(label: "Recipients", value: peerNames),
                    RecoveryWorkspaceFact(label: "Expires", value: formatted(envelope.expiresAt)),
                    RecoveryWorkspaceFact(label: "QR Chunks", value: qrChunkCount),
                    RecoveryWorkspaceFact(label: "Digest", value: documentDigest),
                    RecoveryWorkspaceFact(label: "Trust Session", value: envelope.trustSessionFingerprint ?? "None")
                ],
                canImportShare: false,
                canRecoverAuthority: !envelope.isExpired && envelope.recipientRole == .authorityPhone
            )
        case .peerShare(let share):
            let hasTrustBinding = envelope.trustSessionFingerprint?.isEmpty == false
            return RecoveryWorkspaceSummary(
                title: "Signed Peer Share Document",
                subtitle: "\(share.peerName) • \(envelope.recipientRole.displayName)",
                recommendation: envelope.isExpired
                    ? "This peer-share document has expired. Generate a new signed transfer before importing."
                    : hasTrustBinding
                        ? "This canonical Numi transfer document is bounded to a live peer-trust session and can move through file or QR transport without exposing editable custody material."
                        : "This document is missing its peer-trust binding and must be replaced before any peer-share import.",
                systemImage: "checkmark.shield.fill",
                tone: envelope.isExpired || !hasTrustBinding ? .critical : .ready,
                facts: [
                    RecoveryWorkspaceFact(label: "Sender Role", value: envelope.senderRole.displayName),
                    RecoveryWorkspaceFact(label: "Recipient", value: envelope.recipientRole.displayName),
                    RecoveryWorkspaceFact(label: "Peer", value: share.peerName),
                    RecoveryWorkspaceFact(label: "Expires", value: formatted(envelope.expiresAt)),
                    RecoveryWorkspaceFact(label: "QR Chunks", value: qrChunkCount),
                    RecoveryWorkspaceFact(label: "Digest", value: documentDigest),
                    RecoveryWorkspaceFact(label: "Trust Session", value: envelope.trustSessionFingerprint ?? "Missing")
                ],
                canImportShare: !envelope.isExpired && hasTrustBinding && envelope.recipientRole != .authorityPhone,
                canRecoverAuthority: false
            )
        }
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
    private static func hexPrefix(_ data: Data, bytes: Int = 8) -> String {
        data.prefix(bytes).map { String(format: "%02x", $0) }.joined()
    }
}
