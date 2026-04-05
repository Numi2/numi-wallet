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
    case recoveryShareImported
    case recoveryShareExported
    case sensitiveWorkspaceScrubbed
    case authorityRecovered
    case panicWipe
    case proofCompleted
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
                .recoveryPrepared, .recoveryShareImported, .recoveryShareExported, .authorityRecovered, .proofCompleted,
                .peerPresenceEstablished:
            return .success
        case .vaultSealed, .privacyShieldRaised, .peerPresenceLost, .sensitiveWorkspaceScrubbed:
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
    static func inspect(text: String) -> RecoveryWorkspaceSummary {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RecoveryWorkspaceSummary(
                title: "Workspace Empty",
                subtitle: "No staged recovery material",
                recommendation: "Use this surface only for bounded local custody actions. The shipping product should eventually replace freeform text with authenticated device-to-device transfer.",
                systemImage: "tray",
                tone: .neutral,
                facts: [],
                canImportShare: false,
                canRecoverAuthority: false
            )
        }

        let decoder = JSONDecoder()
        let data = Data(trimmed.utf8)

        if let envelope = try? decoder.decode(RecoveryTransferEnvelope.self, from: data) {
            switch envelope.payload {
            case .authorityBundle(let shares):
                let peerNames = shares.map(\.peerName).joined(separator: ", ")
                return RecoveryWorkspaceSummary(
                    title: "Signed Authority Recovery Envelope",
                    subtitle: "\(shares.count) fragment(s) for \(envelope.recipientRole.displayName)",
                    recommendation: envelope.isExpired
                        ? "This transfer envelope has expired. Generate a new local recovery transfer before attempting re-enrollment."
                        : "This signed transfer envelope is bounded to authority recovery. It should replace raw bundle handling wherever possible.",
                    systemImage: "checkmark.shield.fill",
                    tone: envelope.isExpired ? .critical : .ready,
                    facts: [
                        RecoveryWorkspaceFact(label: "Sender Role", value: envelope.senderRole.displayName),
                        RecoveryWorkspaceFact(label: "Recipients", value: peerNames),
                        RecoveryWorkspaceFact(label: "Expires", value: formatted(envelope.expiresAt)),
                        RecoveryWorkspaceFact(label: "Trust Session", value: envelope.trustSessionFingerprint ?? "None")
                    ],
                    canImportShare: false,
                    canRecoverAuthority: !envelope.isExpired && envelope.recipientRole == .authorityPhone
                )
            case .peerShare(let share):
                return RecoveryWorkspaceSummary(
                    title: "Signed Peer Share Envelope",
                    subtitle: "\(share.peerName) • \(envelope.recipientRole.displayName)",
                    recommendation: envelope.isExpired
                        ? "This transfer envelope has expired. Generate a new local recovery transfer before importing."
                        : "This signed transfer envelope is the preferred transitional format for peer share handling until authenticated device transfer fully replaces workspace staging.",
                    systemImage: "checkmark.shield.fill",
                    tone: envelope.isExpired ? .critical : .ready,
                    facts: [
                        RecoveryWorkspaceFact(label: "Sender Role", value: envelope.senderRole.displayName),
                        RecoveryWorkspaceFact(label: "Recipient", value: envelope.recipientRole.displayName),
                        RecoveryWorkspaceFact(label: "Peer", value: share.peerName),
                        RecoveryWorkspaceFact(label: "Expires", value: formatted(envelope.expiresAt))
                    ],
                    canImportShare: !envelope.isExpired && envelope.recipientRole != .authorityPhone,
                    canRecoverAuthority: false
                )
            }
        }

        if let shares = try? decoder.decode([RecoveryShareEnvelope].self, from: data), !shares.isEmpty {
            let peerNames = shares.map(\.peerName).joined(separator: ", ")
            let packageIDs = Set(shares.map { $0.recoveryPackage.packageID.uuidString.prefix(8).description }).sorted().joined(separator: ", ")
            let latest = shares.map(\.createdAt).max() ?? Date()

            return RecoveryWorkspaceSummary(
                title: "Recovery Quorum Staged",
                subtitle: "\(shares.count) peer fragment(s) loaded",
                recommendation: "This payload can re-enroll a new authority device after local approval, but it remains a legacy raw bundle. Prefer signed transfer envelopes instead.",
                systemImage: "person.2.badge.key.fill",
                tone: .caution,
                facts: [
                    RecoveryWorkspaceFact(label: "Peers", value: peerNames),
                    RecoveryWorkspaceFact(label: "Package IDs", value: packageIDs),
                    RecoveryWorkspaceFact(label: "Last Created", value: formatted(latest))
                ],
                canImportShare: false,
                canRecoverAuthority: true
            )
        }

        if let share = try? decoder.decode(RecoveryShareEnvelope.self, from: data) {
            return RecoveryWorkspaceSummary(
                title: "Peer Share Staged",
                subtitle: "\(share.peerName) • \(share.peerKind.displayName)",
                recommendation: "This payload can be imported into the matching peer role, but it remains a legacy raw share. Prefer signed transfer envelopes instead.",
                systemImage: "person.badge.key.fill",
                tone: .caution,
                facts: [
                    RecoveryWorkspaceFact(label: "Device", value: abbreviated(share.deviceID, prefix: 8)),
                    RecoveryWorkspaceFact(label: "Package", value: share.recoveryPackage.packageID.uuidString.prefix(8).description),
                    RecoveryWorkspaceFact(label: "Root Digest", value: hexPrefix(share.rootKeyDigest)),
                    RecoveryWorkspaceFact(label: "Created", value: formatted(share.createdAt))
                ],
                canImportShare: true,
                canRecoverAuthority: false
            )
        }

        return RecoveryWorkspaceSummary(
            title: "Workspace Unreadable",
            subtitle: "Staged text is not a recognized recovery payload",
            recommendation: "Only a single peer share or a full quorum bundle should be staged here. Any other payload should be cleared.",
            systemImage: "exclamationmark.triangle.fill",
            tone: .critical,
            facts: [
                RecoveryWorkspaceFact(label: "Bytes", value: "\(data.count)"),
                RecoveryWorkspaceFact(label: "Status", value: "JSON payload did not match the expected recovery structures")
            ],
            canImportShare: false,
            canRecoverAuthority: false
        )
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func abbreviated(_ value: String, prefix: Int) -> String {
        let leading = value.prefix(prefix)
        return value.count > prefix ? "\(leading)…" : String(leading)
    }

    private static func hexPrefix(_ data: Data, bytes: Int = 8) -> String {
        data.prefix(bytes).map { String(format: "%02x", $0) }.joined()
    }
}
