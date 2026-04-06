import SwiftUI
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private struct NumiImmersiveLayoutMetrics {
    let width: CGFloat
    let isCompact: Bool
    let contentMaxWidth: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let titleSize: CGFloat
    let footerHorizontalPadding: CGFloat
    let footerBottomPadding: CGFloat

    init(width: CGFloat) {
        self.width = width
        isCompact = width < 760

        if width >= 1440 {
            contentMaxWidth = 1120
        } else if width >= 1024 {
            contentMaxWidth = 980
        } else {
            contentMaxWidth = .infinity
        }

        horizontalPadding = width < 430 ? 16 : (isCompact ? 18 : 22)
        topPadding = isCompact ? 84 : 110
        bottomPadding = isCompact ? 138 : 150
        titleSize = width < 430 ? 28 : (isCompact ? 30 : 34)
        footerHorizontalPadding = width < 430 ? 16 : 20
        footerBottomPadding = width < 430 ? 18 : 10
    }
}

enum NumiImmersiveSurface: String, Identifiable {
    case authorityCeremony
    case vaultChamber
    case transitComposer
    case recoveryStudio
    case ecosystemGraph
    case trustLedger

    var id: String { rawValue }
}

struct NumiEcosystemRole: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    let accent: Color
    let readiness: Double
}

struct NumiEcosystemRoleCard: View {
    let role: NumiEcosystemRole

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(role.accent.opacity(0.18))
                Image(systemName: role.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(role.title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(role.subtitle)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(role.accent)
            }

            Text(role.detail)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.68))

            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [role.accent, Color.white.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: max(22, 176 * role.readiness))
                    }

                Text("Readiness \(Int(role.readiness * 100))%")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.58))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(role.accent.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

struct NumiAuthorityCeremonyView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let isInitialized: Bool
    let peerPresent: Bool
    let peerStatus: String
    let securityPosture: AppleSecurityPosture
    let pairingCode: String
    let statusMessage: String
    let onDismiss: () -> Void
    let onInitialize: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        NumiImmersiveShell(
            eyebrow: "Authority Ceremony",
            title: isInitialized ? "Authority root is established" : "Create the iPhone authority root",
            subtitle: "This is the moment the product should feel unmistakably unlike an exchange app: local, explicit, private, and hardware-bound.",
            accent: NumiPalette.gold,
            onDismiss: onDismiss
        ) {
            NumiImmersiveStage(
                title: isInitialized ? "Authority live" : "Establish authority",
                subtitle: isInitialized ? "Hardware-backed root already present" : "No seed phrase. No cloud restore. No ambient trust.",
                detail: isInitialized ? "Pairing code \(pairingCode)" : "Pairing code will remain visible so peers can be enrolled next.",
                accent: NumiPalette.gold
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 220, maximum: horizontalSizeClass == .compact ? 280 : 320), spacing: 14)], spacing: 14) {
                NumiImmersiveInfoCard(
                    title: "Sovereignty",
                    message: "The authority device remains the only normal signing lane. Other Apple devices reinforce trust without turning into mirrored wallets.",
                    icon: "hand.raised.fill",
                    accent: NumiPalette.aqua
                )

                NumiImmersiveInfoCard(
                    title: "Privacy",
                    message: "Balances and reserve state remain absent until policy is satisfied. Sensitive state redacts on background, capture, and protected-data loss.",
                    icon: "eye.slash.fill",
                    accent: NumiPalette.mint
                )

                NumiImmersiveInfoCard(
                    title: "Apple Trust Fabric",
                    message: "\(securityPosture.shortDescriptor.capitalized). Preferred path: \(securityPosture.preferredTrustTransport).",
                    icon: "checkmark.shield.fill",
                    accent: NumiPalette.gold
                )

                NumiImmersiveInfoCard(
                    title: "Physical Trust",
                    message: peerPresent ? "A peer trust session is active. \(peerStatus)." : "Peer presence is still absent. Recovery and vault use should continue to require deliberate nearby trust.",
                    icon: "dot.radiowaves.left.and.right",
                    accent: NumiPalette.coral
                )
            }

            NumiImmersiveLogCard(message: statusMessage)
        } footer: {
            HStack(spacing: 12) {
                NumiImmersiveButton(
                    title: "Close",
                    icon: "xmark",
                    accent: Color.white.opacity(0.18),
                    foreground: .white,
                    action: onDismiss
                )

                NumiImmersiveButton(
                    title: isInitialized ? "Refresh Rail" : "Establish Authority",
                    icon: isInitialized ? "arrow.clockwise.circle.fill" : "sparkles",
                    accent: NumiPalette.gold,
                    foreground: NumiPalette.ink,
                    action: {
                        if isInitialized {
                            onRefresh()
                        } else {
                            onInitialize()
                        }
                    }
                )
            }
        }
    }
}

struct NumiVaultChamberView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let isInitialized: Bool
    let isVaultUnlocked: Bool
    let peerPresent: Bool
    let peerStatus: String
    let shouldRedact: Bool
    let dayBalance: String
    let vaultBalance: String
    let payReadiness: String
    let onDismiss: () -> Void
    let onUnlock: () -> Void
    let onLock: () -> Void

    var body: some View {
        NumiImmersiveShell(
            eyebrow: "Vault Chamber",
            title: isVaultUnlocked ? "Privileged reserve is live in memory" : "Vault remains absent until conditions are met",
            subtitle: "Vault should feel like a deliberate room you enter briefly, not a number hidden behind a disclosure triangle.",
            accent: NumiPalette.mint,
            onDismiss: onDismiss
        ) {
            NumiImmersiveStage(
                title: isVaultUnlocked ? vaultBalance : "Sealed",
                subtitle: isVaultUnlocked ? "Reserve chamber revealed" : "Reserve chamber sealed",
                detail: payReadiness,
                accent: NumiPalette.mint
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 220, maximum: horizontalSizeClass == .compact ? 280 : 320), spacing: 14)], spacing: 14) {
                NumiImmersiveInfoCard(
                    title: "Day Lane",
                    message: dayBalance,
                    icon: "sun.max.fill",
                    accent: NumiPalette.aqua
                )

                NumiImmersiveInfoCard(
                    title: "Vault State",
                    message: vaultBalance,
                    icon: "lock.shield.fill",
                    accent: NumiPalette.gold
                )

                NumiImmersiveInfoCard(
                    title: "Peer Trust",
                    message: peerStatus,
                    icon: "checkmark.seal.fill",
                    accent: NumiPalette.mint
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Policy checks")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                NumiRequirementRow(title: "Authority initialized", passed: isInitialized, accent: NumiPalette.gold)
                NumiRequirementRow(title: "Peer physically present", passed: peerPresent, accent: NumiPalette.aqua)
                NumiRequirementRow(title: "No active privacy redaction", passed: !shouldRedact, accent: NumiPalette.coral)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        } footer: {
            HStack(spacing: 12) {
                NumiImmersiveButton(
                    title: "Close",
                    icon: "xmark",
                    accent: Color.white.opacity(0.18),
                    foreground: .white,
                    action: onDismiss
                )

                NumiImmersiveButton(
                    title: isVaultUnlocked ? "Seal Chamber" : "Unlock Chamber",
                    icon: isVaultUnlocked ? "lock.fill" : "lock.open.fill",
                    accent: NumiPalette.mint,
                    foreground: NumiPalette.ink,
                    action: {
                        if isVaultUnlocked {
                            onLock()
                        } else {
                            onUnlock()
                        }
                    }
                )
            }
        }
    }
}

struct NumiTransitComposerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let isAuthority: Bool
    let supportsAliasDiscovery: Bool
    let supportsShieldedSend: Bool
    let isInitialized: Bool
    let isVaultUnlocked: Bool
    @Binding var resolveAlias: String
    @Binding var sendAmount: String
    @Binding var sendMaximumFee: String
    @Binding var sendMemo: String
    let resolvedDescriptor: String
    let feeQuote: String
    let readiness: String
    let onDismiss: () -> Void
    let onResolve: () -> Void
    let onSendDay: () -> Void
    let onSendVault: () -> Void

    var body: some View {
        NumiImmersiveShell(
            eyebrow: "Transit Composer",
            title: isAuthority ? "Compose private settlement with less chrome" : "Transit stays bounded to the authority lane",
            subtitle: isAuthority ? "This view reduces the wallet to resolve, amount, fee ceiling, memo, and send actions." : "Peers should understand the boundary clearly instead of being tempted into mirrored spending surfaces.",
            accent: NumiPalette.coral,
            onDismiss: onDismiss
        ) {
            if isAuthority {
                VStack(alignment: .leading, spacing: 14) {
                    if supportsAliasDiscovery {
                        NumiImmersiveField(title: "Resolve Alias", prompt: "saffron-harbor", text: $resolveAlias)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 150 : 180, maximum: horizontalSizeClass == .compact ? 220 : 260), spacing: 12)], spacing: 12) {
                        NumiImmersiveField(title: "Amount", prompt: "12500", text: $sendAmount)
                        NumiImmersiveField(title: "Maximum Fee", prompt: "400", text: $sendMaximumFee)
                    }

                    NumiImmersiveField(title: "Memo", prompt: "Shielded settlement batch", text: $sendMemo)

                    NumiImmersiveInfoCard(
                        title: "Resolved Receive Intent",
                        message: resolvedDescriptor,
                        icon: "dot.radiowaves.forward",
                        accent: NumiPalette.aqua
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 150 : 180, maximum: horizontalSizeClass == .compact ? 220 : 260), spacing: 12)], spacing: 12) {
                        NumiImmersiveButtonCard(
                            title: "Resolve Alias",
                            subtitle: "Request a fresh offline descriptor",
                            icon: "magnifyingglass.circle.fill",
                            accent: NumiPalette.aqua,
                            enabled: supportsAliasDiscovery && !resolveAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            action: onResolve
                        )

                        NumiImmersiveButtonCard(
                            title: "Send From Day",
                            subtitle: "Use daily liquidity first",
                            icon: "sun.max.fill",
                            accent: NumiPalette.gold,
                            enabled: supportsShieldedSend && isInitialized,
                            action: onSendDay
                        )

                        NumiImmersiveButtonCard(
                            title: "Send From Vault",
                            subtitle: "Escalate only when warranted",
                            icon: "lock.open.fill",
                            accent: NumiPalette.mint,
                            enabled: supportsShieldedSend && isVaultUnlocked,
                            action: onSendVault
                        )
                    }

                    HStack(spacing: 12) {
                        NumiMiniStatusCard(title: "Fee Quote", value: feeQuote, accent: NumiPalette.coral)
                        NumiMiniStatusCard(title: "Readiness", value: readiness, accent: NumiPalette.gold)
                    }
                }
            } else {
                NumiImmersiveInfoCard(
                    title: "Peer Boundary",
                    message: "Alias resolution, spend construction, and relay submission remain exclusive to the authority iPhone. This peer remains a recovery and presence instrument.",
                    icon: "hand.raised.fill",
                    accent: NumiPalette.coral
                )
            }
        } footer: {
            HStack(spacing: 12) {
                NumiImmersiveButton(
                    title: "Close",
                    icon: "xmark",
                    accent: Color.white.opacity(0.18),
                    foreground: .white,
                    action: onDismiss
                )

                if isAuthority {
                    NumiImmersiveButton(
                        title: "Resolve Now",
                        icon: "magnifyingglass.circle.fill",
                        accent: NumiPalette.coral,
                        foreground: NumiPalette.ink,
                        action: onResolve
                    )
                }
            }
        }
    }
}

struct NumiRecoveryStudioView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isImportingTransfer = false
    @State private var isImportingQRChunks = false
    @State private var selectedQRChunkIndex = 0
    let role: DeviceRole
    let isInitialized: Bool
    let hasRecoveryShare: Bool
    let hasStagedTransfer: Bool
    let canDispatchStagedTransfer: Bool
    let visibleLocalPeerCount: Int
    let pendingIncomingTransferCount: Int
    let pendingIncomingTransferPreview: PendingRecoveryTransferPreview?
    let canApprovePendingIncomingTransfer: Bool
    let stagedTransferFileURL: URL?
    let stagedTransferQRCodeChunks: [RecoveryTransferQRCodeChunk]
    let workspaceSummary: RecoveryWorkspaceSummary
    let peerTrustStatus: String
    let trustedPeers: [TrustedPeerRecord]
    let ledgerEvents: [TrustLedgerEvent]
    let statusMessage: String
    let onDismiss: () -> Void
    let onLoadTransfer: (Data, String) -> Void
    let onLoadTransferQRCodeImages: ([RecoveryTransferImportAsset]) -> Void
    let onClearTransfer: () -> Void
    let onSendStagedTransfer: () -> Void
    let onApproveIncomingTransfer: () -> Void
    let onRejectIncomingTransfer: () -> Void
    let onPrepareRecovery: () -> Void
    let onRecoverAuthority: () -> Void
    let onImportShare: () -> Void
    let onExportShare: () -> Void

    private var consoleEyebrow: String {
        role.isAuthority ? "Authority Recovery Console" : (role == .recoveryMac ? "Peer Custody Console" : "Peer Recovery Console")
    }

    private var consoleTitle: String {
        role.isAuthority
            ? "Authority recovery stays bounded to a live Apple-device quorum"
            : (role == .recoveryMac
                ? "Mac peer keeps recovery custody inspectable, sealed, and explicit"
                : "Peer fragment custody stays sealed until the authority explicitly calls on it")
    }

    private var consoleSubtitle: String {
        role.isAuthority
            ? "Approve inbound deliveries, inspect peer readiness, and re-enroll only from canonical signed bundles."
            : "This device should act like a bounded custody console rather than a second wallet."
    }

    private var operatorSummaryTitle: String {
        role.isAuthority ? "Authority operator posture" : "Peer custody posture"
    }

    private var operatorSummarySubtitle: String {
        role.isAuthority
            ? "The authority iPhone should see inbox state, live recovery-peer readiness, and recent re-enrollment history in one place."
            : "Peer devices should expose only sealed-share custody, inbound approval, and recent transport history."
    }

    private var operatorSummaryRecommendation: String {
        if pendingIncomingTransferCount > 0 {
            return role.isAuthority
                ? "Review the inbound recovery inbox before staging new fragment work or re-enrolling the authority root."
                : "Approve or reject the pending inbound delivery before it enters local peer custody."
        }
        if role.isAuthority, workspaceSummary.canRecoverAuthority {
            return "A canonical authority bundle is staged and ready for explicit re-enrollment approval."
        }
        if role.isAuthority {
            return "Prepare or import bounded recovery bundles. Never move editable recovery material through the authority lane."
        }
        if hasRecoveryShare {
            return "Keep the peer fragment sealed until the authority explicitly requests a quorum or export action."
        }
        return "Import only canonical signed peer-share documents or explicit local deliveries. This device should never hold editable recovery state."
    }

    private var operatorSummaryFacts: [RecoveryWorkspaceFact] {
        var facts: [RecoveryWorkspaceFact] = [
            RecoveryWorkspaceFact(label: "Trust", value: peerTrustStatus),
            RecoveryWorkspaceFact(label: "Inbox", value: inboxStatusLabel),
            RecoveryWorkspaceFact(label: "Reachable", value: reachabilityLabel)
        ]

        if role.isAuthority {
            facts.insert(
                RecoveryWorkspaceFact(label: "Authority", value: isInitialized ? "Root Established" : "Root Missing"),
                at: 0
            )
            facts.append(
                RecoveryWorkspaceFact(label: "Recovery Mesh", value: "\(activeRecoveryPeerCount) active / \(recoveryPeerCount) known")
            )
        } else {
            facts.insert(
                RecoveryWorkspaceFact(label: "Share", value: hasRecoveryShare ? "Fragment Present" : "Fragment Missing"),
                at: 0
            )
            facts.append(
                RecoveryWorkspaceFact(label: "Workspace", value: hasStagedTransfer ? "Signed Transfer Staged" : "Lane Idle")
            )
        }

        return facts
    }

    private var recoveryMeshPeers: [TrustedPeerRecord] {
        Array(
            trustedPeers
                .filter { $0.capabilities.contains(.recoveryTransfer) || $0.capabilities.contains(.recoveryApproval) }
                .prefix(4)
        )
    }

    private var recoveryPeerCount: Int {
        trustedPeers.filter { $0.capabilities.contains(.recoveryTransfer) || $0.capabilities.contains(.recoveryApproval) }.count
    }

    private var activeRecoveryPeerCount: Int {
        trustedPeers.filter {
            ($0.capabilities.contains(.recoveryTransfer) || $0.capabilities.contains(.recoveryApproval)) && $0.isCurrentTrust
        }.count
    }

    private var recoveryAuditEvents: [TrustLedgerEvent] {
        Array(
            ledgerEvents
                .filter { event in
                    switch event.kind {
                    case .peerSessionEstablished, .peerSessionSealed, .peerSessionExpired, .peerRevoked,
                            .recoveryEnvelopePrepared, .recoveryEnvelopeConsumed:
                        return true
                    }
                }
                .prefix(6)
        )
    }

    private var inboxStatusLabel: String {
        if pendingIncomingTransferCount == 0 {
            return "Clear"
        }
        return "\(pendingIncomingTransferCount) waiting"
    }

    private var reachabilityLabel: String {
        if visibleLocalPeerCount == 0 {
            return "No peer visible"
        }
        return "\(visibleLocalPeerCount) endpoint\(visibleLocalPeerCount == 1 ? "" : "s") visible"
    }

    private var transferLaneNarrative: String {
        if hasStagedTransfer {
            return role.isAuthority
                ? "A canonical signed recovery document is staged locally. Move it through the system share sheet, bounded QR lane, or direct local-session dispatch, then clear it after the custody action completes."
                : "A canonical signed custody document is staged locally. Deliver it only through bounded file, QR, or authenticated local-session transport, then clear it after the explicit custody action completes."
        }

        return role.isAuthority
            ? "Numi no longer stages editable recovery JSON. Import a signed authority bundle, approve a pending local delivery, or prepare a new quorum locally before any re-enrollment action."
            : "Numi no longer stages editable recovery JSON. Import a signed peer-share document, approve a pending local delivery, or export a sealed share only through the bounded custody lane."
    }

    var body: some View {
        NumiImmersiveShell(
            eyebrow: consoleEyebrow,
            title: consoleTitle,
            subtitle: consoleSubtitle,
            accent: NumiPalette.aqua,
            onDismiss: onDismiss
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 220, maximum: horizontalSizeClass == .compact ? 280 : 320), spacing: 14)], spacing: 14) {
                NumiImmersiveInfoCard(
                    title: role.isAuthority ? "Authority State" : "Peer State",
                    message: role.isAuthority ? (isInitialized ? "Authority root established" : "Authority root missing") : (hasRecoveryShare ? "Recovery fragment present" : "Recovery fragment absent"),
                    icon: role.isAuthority ? "iphone.gen3" : "ipad.landscape",
                    accent: NumiPalette.gold
                )

                NumiImmersiveInfoCard(
                    title: "Latest Event",
                    message: statusMessage,
                    icon: "terminal.fill",
                    accent: NumiPalette.mint
                )

                NumiImmersiveInfoCard(
                    title: role.isAuthority ? "Authority Inbox" : "Peer Inbox",
                    message: pendingIncomingTransferCount == 0
                        ? (visibleLocalPeerCount == 0 ? "No peer currently discovered" : "\(visibleLocalPeerCount) peer endpoint\(visibleLocalPeerCount == 1 ? "" : "s") visible")
                        : "\(pendingIncomingTransferCount) authenticated transfer\(pendingIncomingTransferCount == 1 ? "" : "s") waiting",
                    icon: pendingIncomingTransferCount == 0 ? "wave.3.right.circle.fill" : "tray.full.fill",
                    accent: pendingIncomingTransferCount == 0 ? NumiPalette.aqua : NumiPalette.gold
                )
            }

            NumiRecoveryOperatorPanel(
                eyebrow: role.isAuthority ? "Authority Doctrine" : "Peer Doctrine",
                title: operatorSummaryTitle,
                subtitle: operatorSummarySubtitle,
                recommendation: operatorSummaryRecommendation,
                icon: role.isAuthority ? "iphone.gen3" : (role == .recoveryMac ? "macwindow.on.rectangle" : "ipad.landscape"),
                accent: role.isAuthority ? NumiPalette.gold : NumiPalette.aqua,
                facts: operatorSummaryFacts
            )

            NumiRecoveryWorkspaceSummaryCard(summary: workspaceSummary)

            if let pendingIncomingTransferPreview {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(role.isAuthority ? "Authority Approval Inbox" : "Peer Approval Inbox")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(pendingIncomingTransferPreview.kindLabel) from \(pendingIncomingTransferPreview.sourceLabel)")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(NumiPalette.gold)
                        }

                        Spacer(minLength: 12)

                        Text("Expires \(pendingIncomingTransferPreview.expiresLabel)")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.56))
                    }

                    Text(pendingIncomingTransferPreview.recommendation)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.72))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 122 : 140, maximum: horizontalSizeClass == .compact ? 180 : 220), spacing: 10)], spacing: 10) {
                        NumiRecoveryInboxFactCard(label: "Sender", value: pendingIncomingTransferPreview.senderRole.displayName)
                        NumiRecoveryInboxFactCard(label: "Recipient", value: pendingIncomingTransferPreview.recipientRole.displayName)
                        NumiRecoveryInboxFactCard(label: "Source", value: pendingIncomingTransferPreview.sourceLabel)
                        NumiRecoveryInboxFactCard(label: "Trust Session", value: pendingIncomingTransferPreview.transcriptFingerprint ?? "None")
                    }

                    HStack(spacing: 12) {
                        NumiImmersiveButton(
                            title: "Reject",
                            icon: "xmark.circle.fill",
                            accent: Color.white.opacity(0.12),
                            foreground: .white,
                            action: onRejectIncomingTransfer
                        )

                        NumiImmersiveButton(
                            title: "Approve Delivery",
                            icon: "tray.and.arrow.down.fill",
                            accent: NumiPalette.gold,
                            foreground: NumiPalette.ink,
                            enabled: canApprovePendingIncomingTransfer,
                            action: onApproveIncomingTransfer
                        )
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(NumiPalette.gold.opacity(0.2), lineWidth: 1)
                        }
                }
            }

            if role.isAuthority, !recoveryMeshPeers.isEmpty {
                NumiRecoveryMeshPanel(peers: recoveryMeshPeers)
            }

            NumiRecoveryAuditPanel(
                role: role,
                events: recoveryAuditEvents
            )

            VStack(alignment: .leading, spacing: 12) {
                Text(role.isAuthority ? "Authority transfer lane" : "Peer custody lane")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(transferLaneNarrative)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.055))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }
                    }
            }

            if !stagedTransferQRCodeChunks.isEmpty {
                NumiRecoveryTransferQRDeckCard(
                    chunks: stagedTransferQRCodeChunks,
                    selectedIndex: $selectedQRChunkIndex
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 150 : 180, maximum: horizontalSizeClass == .compact ? 220 : 260), spacing: 12)], spacing: 12) {
                NumiImmersiveButtonCard(
                    title: "Import Transfer File",
                    subtitle: "Load a canonical signed recovery document from Files or AirDrop",
                    icon: "square.and.arrow.down.on.square.fill",
                    accent: NumiPalette.mint,
                    enabled: true,
                    action: {
                        isImportingTransfer = true
                    }
                )

                NumiImmersiveButtonCard(
                    title: "Import QR Chunks",
                    subtitle: "Assemble a signed recovery document from one or more QR images",
                    icon: "qrcode.viewfinder",
                    accent: NumiPalette.gold,
                    enabled: true,
                    action: {
                        isImportingQRChunks = true
                    }
                )

                if let stagedTransferFileURL {
                    ShareLink(item: stagedTransferFileURL) {
                        NumiRecoveryStudioActionCard(
                            title: "Share Staged Transfer",
                            subtitle: "Hand off the canonical recovery document through the system share sheet",
                            icon: "square.and.arrow.up.fill",
                            accent: NumiPalette.aqua
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NumiImmersiveButtonCard(
                        title: "Share Staged Transfer",
                        subtitle: "Prepare or import a signed recovery transfer first",
                        icon: "square.and.arrow.up.fill",
                        accent: NumiPalette.aqua,
                        enabled: false,
                        action: {}
                    )
                }

                NumiImmersiveButtonCard(
                    title: "Send Over Local Session",
                    subtitle: canDispatchStagedTransfer
                        ? "Request local owner approval, then deliver the staged recovery document directly to a discovered authenticated Numi peer"
                        : "A staged transfer and a reachable authenticated peer matching the recipient role are both required",
                    icon: "wave.3.left.circle.fill",
                    accent: NumiPalette.aqua,
                    enabled: canDispatchStagedTransfer,
                    action: onSendStagedTransfer
                )

                NumiImmersiveButtonCard(
                    title: "Clear Staged Transfer",
                    subtitle: "Remove the current signed transfer document from local memory",
                    icon: "trash.fill",
                    accent: NumiPalette.coral,
                    enabled: hasStagedTransfer,
                    action: onClearTransfer
                )

                if role.isAuthority {
                    NumiImmersiveButtonCard(
                        title: "Generate Recovery Pair",
                        subtitle: "Create local-only recovery fragments",
                        icon: "person.2.fill",
                        accent: NumiPalette.gold,
                        enabled: isInitialized,
                        action: onPrepareRecovery
                    )

                    NumiImmersiveButtonCard(
                        title: "Re-enroll Authority",
                        subtitle: "Restore from the staged recovery bundle",
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        accent: NumiPalette.aqua,
                        enabled: workspaceSummary.canRecoverAuthority,
                        action: onRecoverAuthority
                    )
                } else {
                    NumiImmersiveButtonCard(
                        title: "Import Peer Share",
                        subtitle: "Seal a fragment into local storage",
                        icon: "square.and.arrow.down.fill",
                        accent: NumiPalette.gold,
                        enabled: workspaceSummary.canImportShare,
                        action: onImportShare
                    )

                    NumiImmersiveButtonCard(
                        title: "Export Peer Share",
                        subtitle: "Approve a local fragment export",
                        icon: "square.and.arrow.up.fill",
                        accent: NumiPalette.aqua,
                        enabled: hasRecoveryShare,
                        action: onExportShare
                    )
                }
            }
        } footer: {
            HStack(spacing: 12) {
                NumiImmersiveButton(
                    title: "Close",
                    icon: "xmark",
                    accent: Color.white.opacity(0.18),
                    foreground: .white,
                    action: onDismiss
                )
            }
        }
        .fileImporter(
            isPresented: $isImportingTransfer,
            allowedContentTypes: [.numiRecoveryTransfer],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard let data = try? Data(contentsOf: url) else {
                return
            }
            onLoadTransfer(data, url.lastPathComponent)
        }
        .fileImporter(
            isPresented: $isImportingQRChunks,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result, !urls.isEmpty else {
                return
            }
            let assets: [RecoveryTransferImportAsset] = urls.compactMap { url in
                let scoped = url.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                guard let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return RecoveryTransferImportAsset(data: data, sourceLabel: url.lastPathComponent)
            }
            guard !assets.isEmpty else {
                return
            }
            onLoadTransferQRCodeImages(assets)
        }
        .onChange(of: stagedTransferQRCodeChunks.count) { _, newCount in
            if newCount == 0 {
                selectedQRChunkIndex = 0
            } else {
                selectedQRChunkIndex = min(selectedQRChunkIndex, newCount - 1)
            }
        }
    }
}

private extension UTType {
    static let numiRecoveryTransfer = UTType(
        exportedAs: "numi.recovery-transfer+json",
        conformingTo: .json
    )
}

private struct NumiRecoveryTransferQRDeckCard: View {
    let chunks: [RecoveryTransferQRCodeChunk]
    @Binding var selectedIndex: Int

    private var orderedChunks: [RecoveryTransferQRCodeChunk] {
        chunks.sorted { $0.index < $1.index }
    }

    private var selectedChunk: RecoveryTransferQRCodeChunk? {
        guard orderedChunks.indices.contains(selectedIndex) else { return nil }
        return orderedChunks[selectedIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("QR Transfer Lane")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Render the signed recovery document as bounded QR chunks for human-assisted handoff without exposing editable custody JSON.")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Spacer(minLength: 12)
                Text("\(orderedChunks.count) chunk\(orderedChunks.count == 1 ? "" : "s")")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(NumiPalette.aqua)
            }

            if let selectedChunk {
                HStack(alignment: .center, spacing: 18) {
                    NumiRecoveryTransferQRCodeGraphic(chunk: selectedChunk)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedChunk.label)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)

                        Text("Each QR carries typed chunk metadata, the canonical document digest, and one bounded fragment of the signed transfer document.")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.72))

                        VStack(alignment: .leading, spacing: 6) {
                            NumiQRFact(label: "Digest", value: hexPrefix(selectedChunk.documentDigest))
                            NumiQRFact(label: "Fragment", value: "\(selectedChunk.payloadFragment.count) chars")
                        }

                        HStack(spacing: 10) {
                            Button {
                                selectedIndex = max(0, selectedIndex - 1)
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                            .tint(NumiPalette.aqua)
                            .disabled(selectedIndex == 0)

                            Button {
                                selectedIndex = min(orderedChunks.count - 1, selectedIndex + 1)
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(NumiPalette.gold)
                            .disabled(selectedIndex >= orderedChunks.count - 1)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(NumiPalette.aqua.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private func hexPrefix(_ data: Data, bytes: Int = 8) -> String {
        data.prefix(bytes).map { String(format: "%02x", $0) }.joined()
    }
}

private struct NumiRecoveryTransferQRCodeGraphic: View {
    let chunk: RecoveryTransferQRCodeChunk

    var body: some View {
        VStack(spacing: 10) {
            if let image = NumiQRCodeImageFactory.makeImage(from: try? chunk.qrPayloadString()) {
                image
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.58))
                    }
            }

            Text(chunk.label)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.68))
        }
    }
}

private struct NumiQRFact: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.52))
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
        }
    }
}

private enum NumiQRCodeImageFactory {
    private static let context = CIContext()

    static func makeImage(from payload: String?) -> Image? {
        guard let payload else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "Q"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            return nil
        }

        #if canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #elseif canImport(AppKit)
        return Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
        #else
        return nil
        #endif
    }
}

private struct NumiRecoveryOperatorPanel: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let eyebrow: String
    let title: String
    let subtitle: String
    let recommendation: String
    let icon: String
    let accent: Color
    let facts: [RecoveryWorkspaceFact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(accent.opacity(0.9))

            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(recommendation)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.7))

            if !facts.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 122 : 140, maximum: horizontalSizeClass == .compact ? 190 : 220), spacing: 10)], spacing: 10) {
                    ForEach(facts) { fact in
                        NumiRecoveryInboxFactCard(label: fact.label, value: fact.value)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private struct NumiRecoveryMeshPanel: View {
    let peers: [TrustedPeerRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Mesh")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Known recovery peers and their latest local trust posture.")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Spacer(minLength: 12)
                Text("\(peers.count) peer\(peers.count == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(NumiPalette.gold)
            }

            ForEach(peers) { peer in
                NumiRecoveryMeshPeerCard(peer: peer)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(NumiPalette.gold.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private struct NumiRecoveryMeshPeerCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let peer: TrustedPeerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                    Image(systemName: peer.peerKind == .pad ? "ipad.landscape" : "macbook.and.iphone")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.peerName)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(peer.peerRole.displayName) • \(peer.statusLabel)")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 0)

                if peer.appAttested {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NumiPalette.mint)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 122 : 140, maximum: horizontalSizeClass == .compact ? 190 : 220), spacing: 10)], spacing: 10) {
                NumiRecoveryInboxFactCard(label: "Transport", value: transportLabel)
                NumiRecoveryInboxFactCard(label: "Proximity", value: peer.proximityLabel)
                NumiRecoveryInboxFactCard(label: "Expires", value: peer.lastExpiresAt.formatted(date: .omitted, time: .shortened))
                NumiRecoveryInboxFactCard(label: "Capabilities", value: peer.capabilities.map(\.label).joined(separator: ", "))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                }
        }
    }

    private var accent: Color {
        if peer.isCurrentTrust {
            switch peer.lastTrustLevel {
            case .attestedLocal:
                return NumiPalette.gold
            case .nearbyVerified:
                return NumiPalette.mint
            }
        }
        return NumiPalette.coral
    }

    private var transportLabel: String {
        switch peer.lastTransport {
        case .nearbyInteraction:
            return "Nearby Interaction"
        case .networkFramework:
            return "Network.framework"
        }
    }
}

private struct NumiRecoveryAuditPanel: View {
    let role: DeviceRole
    let events: [TrustLedgerEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.isAuthority ? "Re-enrollment Audit" : "Custody Audit")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(role.isAuthority
                        ? "Recent recovery transfers, peer trust decisions, and authority-lane history."
                        : "Recent peer-share deliveries, trust changes, and local custody history.")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Spacer(minLength: 12)
                Text(events.isEmpty ? "Idle" : "\(events.count) recent")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(NumiPalette.aqua)
            }

            if events.isEmpty {
                Text(role.isAuthority
                    ? "No durable recovery audit exists yet. Establish the recovery mesh or stage a bounded bundle to seed re-enrollment history."
                    : "No durable peer-custody audit exists yet. Import or export a sealed share, or approve a local delivery, to seed this history.")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            } else {
                ForEach(events) { event in
                    NumiRecoveryAuditRow(event: event)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(NumiPalette.aqua.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private struct NumiRecoveryAuditRow: View {
    let event: TrustLedgerEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                Image(systemName: event.kind.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.kind.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(event.occurredAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.48))
                }

                Text(event.summary)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(accent)

                Text(event.detail)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.68))

                if let fingerprint = event.fingerprint {
                    Text(fingerprint)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                }
        }
    }

    private var accent: Color {
        switch event.kind {
        case .peerSessionEstablished:
            return NumiPalette.mint
        case .peerSessionSealed, .peerSessionExpired:
            return NumiPalette.gold
        case .peerRevoked, .recoveryEnvelopeConsumed:
            return NumiPalette.coral
        case .recoveryEnvelopePrepared:
            return NumiPalette.aqua
        }
    }
}

struct NumiEcosystemGraphView: View {
    let roles: [NumiEcosystemRole]
    let onDismiss: () -> Void

    var body: some View {
        NumiImmersiveShell(
            eyebrow: "Apple Device Graph",
            title: "Numi should read as one coherent Apple hardware system",
            subtitle: "Each device gets a sharply bounded role. That restraint is not missing functionality. It is the product.",
            accent: NumiPalette.gold,
            onDismiss: onDismiss
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(roles) { role in
                    NumiEcosystemRoleCard(role: role)
                }
            }
        } footer: {
            HStack(spacing: 12) {
                NumiImmersiveButton(
                    title: "Close",
                    icon: "xmark",
                    accent: Color.white.opacity(0.18),
                    foreground: .white,
                    action: onDismiss
                )
            }
        }
    }
}

private struct NumiRecoveryWorkspaceSummaryCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let summary: RecoveryWorkspaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(summary.title, systemImage: summary.systemImage)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)

            Text(summary.subtitle)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            Text(summary.recommendation)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.7))

            if !summary.facts.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 122 : 140, maximum: horizontalSizeClass == .compact ? 190 : 220), spacing: 10)], spacing: 10) {
                    ForEach(summary.facts) { fact in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(fact.label)
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.white.opacity(0.56))
                            Text(fact.value)
                                .font(.system(.caption, design: .monospaced).weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var tint: Color {
        switch summary.tone {
        case .neutral:
            return NumiPalette.aqua
        case .ready:
            return NumiPalette.mint
        case .caution:
            return NumiPalette.gold
        case .critical:
            return NumiPalette.coral
        }
    }
}

private struct NumiRecoveryInboxFactCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.56))
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiImmersiveShell<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let onDismiss: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: Color,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.onDismiss = onDismiss
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = NumiImmersiveLayoutMetrics(width: geometry.size.width)

            ZStack {
                NumiImmersiveBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: metrics.isCompact ? 18 : 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(eyebrow.uppercased())
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(accent)
                            Text(title)
                                .font(.system(size: metrics.titleSize, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(subtitle)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(2)
                        }

                        content
                    }
                    .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.topPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .top) {
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: metrics.contentMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.isCompact ? 6 : 10)
                }
                .safeAreaInset(edge: .bottom) {
                    footer
                        .frame(maxWidth: metrics.contentMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, metrics.footerHorizontalPadding)
                        .padding(.top, 10)
                        .padding(.bottom, metrics.footerBottomPadding)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 1)
                                }
                                .ignoresSafeArea(edges: .bottom)
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct NumiImmersiveBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let goldSize = min(max(width * 0.9, 260), 420)
            let aquaSize = min(max(width, 320), 460)

            ZStack {
                LinearGradient(
                    colors: [
                        NumiPalette.ink,
                        NumiPalette.night,
                        Color(red: 0.16, green: 0.18, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NumiPalette.gold.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: goldSize * 0.62
                        )
                    )
                    .frame(width: goldSize, height: goldSize)
                    .offset(x: -width * 0.28, y: -width * 0.6)
                    .blur(radius: 30)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NumiPalette.aqua.opacity(0.24), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: aquaSize * 0.57
                        )
                    )
                    .frame(width: aquaSize, height: aquaSize)
                    .offset(x: width * 0.38, y: width * 0.44)
                    .blur(radius: 36)
            }
        }
        .ignoresSafeArea()
    }
}

private struct NumiImmersiveStage: View {
    let title: String
    let subtitle: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(subtitle)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(2)
            Text(detail)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(2)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .background {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private struct NumiImmersiveInfoCard: View {
    let title: String
    let message: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(accent)

            Text(message)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.76))
                .lineLimit(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiImmersiveLogCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operator Log")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.76))
                .lineLimit(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiRequirementRow: View {
    let title: String
    let passed: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(passed ? accent : Color.white.opacity(0.36))
            Text(title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }
}

private struct NumiImmersiveButtonCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(enabled ? accent : Color.white.opacity(0.3))
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(enabled ? .white : Color.white.opacity(0.4))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(enabled ? Color.white.opacity(0.66) : Color.white.opacity(0.34))
                    .lineLimit(2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(enabled ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(enabled ? accent.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct NumiRecoveryStudioActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.66))
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private struct NumiMiniStatusCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(accent)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiImmersiveField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.62))

            Group {
                #if os(macOS)
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                #else
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                #endif
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
    }
}

private struct NumiImmersiveButton: View {
    let title: String
    let icon: String
    let accent: Color
    let foreground: Color
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(accent)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
