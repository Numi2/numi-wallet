import SwiftUI

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
    let role: DeviceRole
    let isInitialized: Bool
    let hasRecoveryShare: Bool
    @Binding var workspaceText: String
    let workspaceSummary: RecoveryWorkspaceSummary
    let statusMessage: String
    let onDismiss: () -> Void
    let onPrepareRecovery: () -> Void
    let onRecoverAuthority: () -> Void
    let onImportShare: () -> Void
    let onExportShare: () -> Void

    var body: some View {
        NumiImmersiveShell(
            eyebrow: "Recovery Studio",
            title: role.isAuthority ? "Recovery remains local to the Apple device graph" : "Peer fragment custody stays sealed and explicit",
            subtitle: "This workspace should feel more like a controlled instrument panel than a generic settings page.",
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
            }

            NumiRecoveryWorkspaceSummaryCard(summary: workspaceSummary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Sensitive workspace")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                TextEditor(text: $workspaceText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(minHeight: 280)
                    .scrollContentBackground(.hidden)
                    .padding(18)
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.055))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }
                    }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 150 : 180, maximum: horizontalSizeClass == .compact ? 220 : 260), spacing: 12)], spacing: 12) {
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
    }
}
