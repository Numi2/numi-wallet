import SwiftUI
import LocalAuthentication

#if canImport(UIKit)
import UIKit
#endif

private struct NumiDashboardLayoutMetrics {
    let width: CGFloat
    let isCompact: Bool
    let contentMaxWidth: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let heroValueFontSize: CGFloat
    let sealSize: CGFloat

    init(width: CGFloat) {
        self.width = width
        isCompact = width < 760

        if width >= 1440 {
            contentMaxWidth = 1240
        } else if width >= 1024 {
            contentMaxWidth = 1100
        } else {
            contentMaxWidth = .infinity
        }

        horizontalPadding = width < 430 ? 16 : (isCompact ? 18 : 28)
        topPadding = width < 430 ? 14 : 18
        bottomPadding = isCompact ? 150 : 170
        sectionSpacing = isCompact ? 18 : 22
        heroValueFontSize = width < 430 ? 34 : 46
        sealSize = width < 430 ? 128 : (isCompact ? 180 : 208)
    }
}

struct WalletDashboardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: WalletAppModel
    @State private var selectedDeck: DashboardDeck = .wallet
    @State private var immersiveSurface: NumiImmersiveSurface?
    @State private var privilegedAction: NumiPrivilegedAction?
    @State private var hasAutoPresentedAuthorityCeremony = false

    @MainActor
    init(model: WalletAppModel, initialDeck: DashboardDeck? = nil) {
        let resolvedDeck = initialDeck ?? DashboardDeck.defaultDeck(for: model.role)
        _model = StateObject(wrappedValue: model)
        _selectedDeck = State(initialValue: resolvedDeck)
    }

    private var prefersCompactColumns: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        withPrivilegedAuthentication {
            GeometryReader { geometry in
                let metrics = NumiDashboardLayoutMetrics(width: geometry.size.width)

                ZStack {
                    NumiBackdrop()

                    ScrollView {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            canopy(isCompact: metrics.isCompact)
                            sovereigntyStage(metrics: metrics)

                            if model.isScreenCaptureActive {
                                captureAlert
                            }

                            deckSelector(isCompact: metrics.isCompact)
                            deckContent(isCompact: metrics.isCompact)
                        }
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.topPadding)
                        .padding(.bottom, metrics.bottomPadding)
                    }
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if scenePhase == .active && !model.shouldRedactUI {
                            bottomCommandDock(contentMaxWidth: metrics.contentMaxWidth, isCompact: metrics.isCompact)
                        }
                    }
                    .task {
                        model.start()
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        model.handleScenePhase(newPhase)
                    }
                    .onChange(of: model.dashboard.isInitialized) { _, isInitialized in
                        if isInitialized, immersiveSurface == .authorityCeremony {
                            immersiveSurface = nil
                        }
                    }
                    .onChange(of: model.latestEvent?.id) { _, _ in
                        playFeedback(for: model.latestEvent)
                    }
                    .onAppear {
                        guard model.role.isAuthority, !model.dashboard.isInitialized, !hasAutoPresentedAuthorityCeremony else { return }
                        hasAutoPresentedAuthorityCeremony = true
                        immersiveSurface = .authorityCeremony
                    }

                    if scenePhase != .active || model.shouldRedactUI {
                        privacyShield
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86), value: selectedDeck)
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86), value: model.dashboard.isVaultUnlocked)
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86), value: model.peerPresent)
        .sensoryFeedback(.selection, trigger: selectedDeck)
        .numiModal(item: $immersiveSurface) { surface in
            withPrivilegedAuthentication {
                immersiveSurfaceView(surface)
            }
        }
    }

    @ViewBuilder
    private func canopy(isCompact: Bool) -> some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 16) {
                brandLockup(isCompact: true)
                statusBadgeStack(alignment: .leading)
            }
        } else {
            ViewThatFits {
                HStack(alignment: .top, spacing: 18) {
                    brandLockup(isCompact: false)
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 12) {
                        statusBadgeStack(alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    brandLockup(isCompact: false)
                    statusBadgeStack(alignment: .leading)
                }
            }
        }
    }

    private func brandLockup(isCompact: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [NumiPalette.aqua.opacity(0.95), NumiPalette.gold, Color.white.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Circle()
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: isCompact ? 22 : 24, weight: .black))
                    .foregroundStyle(NumiPalette.ink)
            }
            .frame(width: isCompact ? 52 : 58, height: isCompact ? 52 : 58)
            .shadow(color: NumiPalette.gold.opacity(0.22), radius: 24, x: 0, y: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("NUMI")
                    .font(.system(size: isCompact ? 28 : 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Private wallet, Apple-bound.")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
    }

    private func statusBadgeStack(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            ViewThatFits {
                HStack(spacing: 8) {
                    rolePill
                    vaultPill
                    peerPill
                }

                VStack(alignment: alignment, spacing: 8) {
                    HStack(spacing: 8) {
                        rolePill
                        vaultPill
                    }

                    peerPill
                }
            }
        }
    }

    private func sovereigntyStage(metrics: NumiDashboardLayoutMetrics) -> some View {
        NumiGlassPanel(
            eyebrow: "Sovereign Chamber",
            title: heroTitle,
            subtitle: heroNarrative,
            icon: heroIcon,
            accent: heroAccent
        ) {
            if metrics.isCompact {
                ViewThatFits {
                    HStack(alignment: .center, spacing: 16) {
                        stageNarrative(heroValueFontSize: metrics.heroValueFontSize)
                        stageSeal(size: metrics.sealSize, isCompact: true, fillWidth: false)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        stageNarrative(heroValueFontSize: metrics.heroValueFontSize)
                        stageSeal(size: metrics.sealSize, isCompact: true)
                    }
                }
            } else {
                ViewThatFits {
                    HStack(alignment: .top, spacing: 18) {
                        stageNarrative(heroValueFontSize: metrics.heroValueFontSize)
                        stageSeal(size: metrics.sealSize, isCompact: false)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        stageNarrative(heroValueFontSize: metrics.heroValueFontSize)
                        stageSeal(size: metrics.sealSize, isCompact: false)
                    }
                }
            }

            stageSignals(isCompact: metrics.isCompact)
            primaryActionCluster(isCompact: metrics.isCompact)
        }
    }

    private func stageNarrative(heroValueFontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(heroValue)
                    .font(.system(size: heroValueFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.72)
                    .privacySensitive(model.role.isAuthority)

                Text(heroCaption)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(heroAccent)
            }

            HStack(spacing: 10) {
                NumiStateBadge(title: missionStatusTitle, icon: missionStatusIcon, tint: missionStatusTint)
                NumiStateBadge(title: privacyPostureTitle, icon: "eye.slash.fill", tint: NumiPalette.aqua)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stageSeal(size: CGFloat, isCompact: Bool, fillWidth: Bool = true) -> some View {
        HStack {
            Spacer(minLength: 0)
            NumiChamberSeal(
                title: sealTitle,
                subtitle: sealSubtitle,
                detail: sealDetail,
                progress: sovereigntyReadiness,
                accent: heroAccent,
                live: model.dashboard.isVaultUnlocked,
                size: size
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: fillWidth ? (isCompact ? .infinity : max(260, size + 32)) : size + 16)
    }

    private func stageSignals(isCompact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 132 : 150, maximum: isCompact ? 190 : 240), spacing: 12)], spacing: 12) {
            ForEach(heroSignals) { signal in
                NumiSignalTile(signal: signal)
            }
        }
    }

    @ViewBuilder
    private func primaryActionCluster(isCompact: Bool) -> some View {
        let columns = [GridItem(.adaptive(minimum: isCompact ? 132 : 180, maximum: 260), spacing: 12)]

        LazyVGrid(columns: columns, spacing: 12) {
            if model.role.isAuthority {
                NumiFeatureButton(
                    title: model.dashboard.isInitialized ? "Review Authority" : "Begin Authority Ceremony",
                    subtitle: model.dashboard.isInitialized ? "Inspect the trust root" : "Set up the authority device",
                    icon: model.dashboard.isInitialized ? "checkmark.shield.fill" : "sparkles",
                    accent: NumiPalette.gold,
                    enabled: true
                ) {
                    immersiveSurface = .authorityCeremony
                }

                NumiFeatureButton(
                    title: model.dashboard.isVaultUnlocked ? "Seal Vault Chamber" : "Enter Vault Chamber",
                    subtitle: model.dashboard.isVaultUnlocked ? "Clear live vault memory" : "Open the sealed reserve",
                    icon: model.dashboard.isVaultUnlocked ? "lock.fill" : "lock.open.fill",
                    accent: NumiPalette.mint,
                    enabled: model.dashboard.isInitialized
                ) {
                    immersiveSurface = .vaultChamber
                }
            } else {
                NumiFeatureButton(
                    title: "Open Recovery Studio",
                    subtitle: model.hasRecoveryShare ? "Review fragment custody" : "Import a sealed share",
                    icon: "person.crop.rectangle.stack.fill",
                    accent: NumiPalette.aqua,
                    enabled: model.hasRecoveryShare || hasRecoveryWorkspaceText
                ) {
                    immersiveSurface = .recoveryStudio
                }
            }
        }
    }

    @ViewBuilder
    private func deckSelector(isCompact: Bool) -> some View {
        if isCompact {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DashboardDeck.allCases) { deck in
                        Button {
                            selectedDeck = deck
                        } label: {
                            NumiDeckChip(deck: deck, selected: selectedDeck == deck)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        } else {
            HStack(spacing: 10) {
                ForEach(DashboardDeck.allCases) { deck in
                    Button {
                        selectedDeck = deck
                    } label: {
                        NumiDeckChip(deck: deck, selected: selectedDeck == deck)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func deckContent(isCompact: Bool) -> some View {
        switch selectedDeck {
        case .wallet:
            walletDeck(isCompact: isCompact)
        case .transit:
            transitDeck(isCompact: isCompact)
        case .custody:
            custodyDeck(isCompact: isCompact)
        }
    }

    private func walletDeck(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            compartmentField(isCompact: isCompact)
            appleTrustFabric
            trustTopology
            privacyRail
            statusCard
        }
    }

    private func compartmentField(isCompact: Bool) -> some View {
        NumiGlassPanel(
            eyebrow: "Wallet Constitution",
            title: "Day and vault stay visually distinct",
            subtitle: "Daily funds stay visible. Vault funds stay sealed.",
            icon: "square.split.2x1.fill",
            accent: NumiPalette.gold
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 180 : 260, maximum: isCompact ? 360 : 420), spacing: 14)], spacing: 14) {
                NumiCompartmentCard(
                    title: "Day Wallet",
                    tone: "Operating liquidity",
                    balance: model.dashboard.dayBalance,
                    state: model.dashboard.isInitialized ? "Ready for daily movement" : "Authority root not established",
                    accent: NumiPalette.aqua,
                    icon: "sun.max.fill",
                    sensitive: true
                )

                NumiCompartmentCard(
                    title: "Vault Chamber",
                    tone: model.dashboard.isVaultUnlocked ? "Privileged reserve is live" : "Reserve remains sealed",
                    balance: model.dashboard.vaultBalance ?? hiddenVaultBalanceCopy,
                    state: model.dashboard.isVaultUnlocked ? "Live in memory now" : "Requires local auth plus peer presence",
                    accent: NumiPalette.gold,
                    icon: "lock.shield.fill",
                    sensitive: true
                )
            }
        }
    }

    private var appleTrustFabric: some View {
        NumiGlassPanel(
            eyebrow: "Apple Trust Fabric",
            title: "Platform trust stays explicit",
            subtitle: "Keep the Apple security posture readable.",
            icon: "checkmark.shield.fill",
            accent: NumiPalette.aqua
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: prefersCompactColumns ? 132 : 150, maximum: prefersCompactColumns ? 210 : 230), spacing: 12)], spacing: 12) {
                ForEach(securityPostureSignals) { signal in
                    NumiSignalTile(signal: signal)
                }
            }

            Label(model.securityPosture.headline, systemImage: "shield.checkered")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            Text(model.securityPosture.primaryRecommendation)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(2)

            NumiFeatureButton(
                title: "Open Device Graph",
                subtitle: "Review Apple device roles",
                icon: "apple.logo",
                accent: NumiPalette.gold,
                enabled: true
            ) {
                immersiveSurface = .ecosystemGraph
            }
        }
    }

    private var trustTopology: some View {
        NumiGlassPanel(
            eyebrow: "Trust Topology",
            title: "Nearby trust stays local",
            subtitle: "Keep co-presence visible and short-lived.",
            icon: "point.3.connected.trianglepath.dotted",
            accent: NumiPalette.mint
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: prefersCompactColumns ? 132 : 150, maximum: prefersCompactColumns ? 210 : 230), spacing: 12)], spacing: 12) {
                ForEach(trustSignals) { signal in
                    NumiSignalTile(signal: signal)
                }
            }

            NumiPeerTrustCard(session: model.peerTrustSession)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: prefersCompactColumns ? 144 : 160, maximum: prefersCompactColumns ? 220 : 240), spacing: 12)], spacing: 12) {
                NumiFeatureButton(
                    title: "Trust iPad Peer",
                    subtitle: "Start nearby trust",
                    icon: "ipad.landscape",
                    accent: NumiPalette.aqua,
                    enabled: model.role.isAuthority
                ) {
                    model.establishPeerTrust(with: .pad)
                }

                NumiFeatureButton(
                    title: "Trust Mac Peer",
                    subtitle: "Start attested trust",
                    icon: "macbook.and.iphone",
                    accent: NumiPalette.gold,
                    enabled: model.role.isAuthority
                ) {
                    model.establishPeerTrust(with: .mac)
                }

                NumiFeatureButton(
                    title: "Seal Trust Session",
                    subtitle: "End the active session",
                    icon: "xmark.circle.fill",
                    accent: NumiPalette.coral,
                    enabled: model.peerTrustSession != nil
                ) {
                    model.clearPeerTrust()
                }

                NumiFeatureButton(
                    title: "Open Trust Ledger",
                    subtitle: "Review local peer history",
                    icon: "list.clipboard.fill",
                    accent: NumiPalette.gold,
                    enabled: true
                ) {
                    immersiveSurface = .trustLedger
                }
            }
        }
    }

    private var privacyRail: some View {
        NumiGlassPanel(
            eyebrow: "Privacy Rail",
            title: "Private state stays quiet",
            subtitle: "Refresh posture and proof policy without leaving the rail.",
            icon: "eye.slash.circle.fill",
            accent: NumiPalette.aqua
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: prefersCompactColumns ? 132 : 150, maximum: prefersCompactColumns ? 200 : 220), spacing: 12)], spacing: 12) {
                ForEach(privacySignals) { signal in
                    NumiSignalTile(signal: signal)
                }
            }

            if model.role.isAuthority {
                Picker("Proof Policy", selection: $model.proofPolicy) {
                    ForEach(ProofPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.segmented)

                NumiFeatureButton(
                    title: "Run Local Proof",
                    subtitle: "Verify the current venue",
                    icon: "cpu.fill",
                    accent: NumiPalette.coral,
                    enabled: model.dashboard.isInitialized
                ) {
                    model.runProof()
                }
            }
        }
    }

    private func transitDeck(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            NumiFeatureButton(
                title: model.role.isAuthority ? "Open Transit Composer" : "Open Peer Transit View",
                subtitle: model.role.isAuthority ? "Open send flow" : "View transit boundary",
                icon: "paperplane.circle.fill",
                accent: NumiPalette.coral,
                enabled: true
            ) {
                immersiveSurface = .transitComposer
            }
            receivePosture
            if model.role.isAuthority {
                routeReadiness
            }
            statusCard
        }
    }

    private var receivePosture: some View {
        NumiGlassPanel(
            eyebrow: "Receive Posture",
            title: "Private receive stays intent-based, not address-based",
            subtitle: "Rotate receive intent and refresh state.",
            icon: "antenna.radiowaves.left.and.right",
            accent: NumiPalette.gold
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: prefersCompactColumns ? 132 : 150, maximum: prefersCompactColumns ? 200 : 220), spacing: 12)], spacing: 12) {
                ForEach(routeSignals) { signal in
                    NumiSignalTile(signal: signal)
                }
            }

            if model.role.isAuthority {
                NumiFeatureButton(
                    title: "Refresh Shielded State",
                    subtitle: "Refresh before sending",
                    icon: "arrow.clockwise.circle.fill",
                    accent: NumiPalette.mint,
                    enabled: model.supportsPIRStateUpdates && model.dashboard.isInitialized
                ) {
                    model.refreshShieldedState()
                }
            }
        }
    }

    private var routeReadiness: some View {
        NumiGlassPanel(
            eyebrow: "Transit Guidance",
            title: "Readiness should stay human-readable",
            subtitle: "Show the next required step.",
            icon: "list.bullet.rectangle.portrait.fill",
            accent: NumiPalette.mint
        ) {
            ForEach(transitGuidance) { step in
                NumiTimelineRow(step: step)
            }
        }
    }

    private func custodyDeck(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            recoveryOverview
            if model.role.isAuthority {
                custodyOperations(isCompact: isCompact)
            }
            statusCard
        }
    }

    private var recoveryOverview: some View {
        NumiGlassPanel(
            eyebrow: "Recovery Overview",
            title: model.role.isAuthority ? "Recovery stays staged, not ambient" : "Peer share stays sealed",
            subtitle: model.role.isAuthority ? "Open the studio only when fragment work is needed." : "This device only exists for deliberate fragment custody.",
            icon: "person.crop.rectangle.stack.fill",
            accent: NumiPalette.aqua
        ) {
            NumiWorkspaceSummaryCard(summary: model.recoveryWorkspaceSummary)

            NumiFeatureButton(
                title: "Open Recovery Studio",
                subtitle: model.role.isAuthority ? "Prepare or restore fragments" : "Import or export a local share",
                icon: "person.crop.rectangle.stack.fill",
                accent: NumiPalette.aqua,
                enabled: true
            ) {
                immersiveSurface = .recoveryStudio
            }
        }
    }

    private func custodyOperations(isCompact: Bool) -> some View {
        NumiGlassPanel(
            eyebrow: model.role.isAuthority ? "Authority Controls" : "Peer Role",
            title: model.role.isAuthority ? "Custody actions stay explicit and somewhat ceremonial" : "Peer devices keep a narrow trust role",
            subtitle: model.role.isAuthority
                ? "Keep high-impact actions explicit."
                : "Peers keep a narrow role.",
            icon: model.role.isAuthority ? "iphone.gen3" : "ipad.landscape.badge.play",
            accent: model.role.isAuthority ? NumiPalette.gold : NumiPalette.aqua
        ) {
            if model.role.isAuthority {
                VStack(alignment: .leading, spacing: 14) {
                    NumiInputField(title: "Discovery Alias", prompt: "saffron-harbor", text: $model.alias)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 136 : 175, maximum: isCompact ? 230 : 250), spacing: 12)], spacing: 12) {
                        NumiFeatureButton(
                            title: "Establish Authority",
                            subtitle: "Create the root",
                            icon: "sparkles",
                            accent: NumiPalette.gold,
                            enabled: !model.dashboard.isInitialized
                        ) {
                            model.initializeAuthorityWallet()
                        }

                        NumiFeatureButton(
                            title: "Register Alias",
                            subtitle: "Publish alias",
                            icon: "at.circle.fill",
                            accent: NumiPalette.aqua,
                            enabled: model.supportsAliasDiscovery && model.dashboard.isInitialized && !trimmedAlias.isEmpty
                        ) {
                            model.registerAlias()
                        }

                        NumiFeatureButton(
                            title: "Rotate Day Intent",
                            subtitle: "Rotate day intent",
                            icon: "sun.max.circle.fill",
                            accent: NumiPalette.aqua,
                            enabled: model.dashboard.isInitialized
                        ) {
                            model.rotateDescriptor(for: .day)
                        }

                        NumiFeatureButton(
                            title: "Rotate Vault Intent",
                            subtitle: "Rotate vault intent",
                            icon: "lock.circle.fill",
                            accent: NumiPalette.gold,
                            enabled: model.dashboard.isVaultUnlocked
                        ) {
                            model.rotateDescriptor(for: .vault)
                        }

                        NumiFeatureButton(
                            title: "Destroy Local Unwrap",
                            subtitle: "Force recovery",
                            icon: "flame.fill",
                            accent: NumiPalette.coral,
                            enabled: model.dashboard.isInitialized
                        ) {
                            requestPrivilegedAction(.panicWipe)
                        }
                    }
                }
            } else {
                roleRestriction(
                    title: "Authority operations are unavailable here",
                    detail: "Initialization, signing, receive rotation, and panic behavior all belong to the authority iPhone. This build is running as \(model.role.displayName)."
                )
            }
        }
    }

    private var statusCard: some View {
        NumiGlassPanel(
            eyebrow: "Operator Log",
            title: "One quiet channel for the wallet’s latest meaningful event",
            subtitle: "Latest wallet event.",
            icon: "terminal.fill",
            accent: NumiPalette.aqua
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let latest = model.latestEvent {
                    NumiEventRow(event: latest, prominent: true)
                } else {
                    Text(model.statusMessage)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineSpacing(5)
                        .privacySensitive()
                }

            }
        }
    }

    private var captureAlert: some View {
        NumiGlassPanel(
            eyebrow: "Privacy Lockdown",
            title: "Screen capture was detected and sensitive state was cleared",
            subtitle: "Sensitive values stay redacted.",
            icon: "record.circle.fill",
            accent: NumiPalette.coral
        ) {
            Text("Vault memory has already been cleared. The system will stay visibly redacted until the privacy boundary is safe again.")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.76))
        }
    }

    private var privacyShield: some View {
        ZStack {
            NumiBackdrop()

            Rectangle()
                .fill(.black.opacity(0.46))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                NumiChamberSeal(
                    title: "Redacted",
                    subtitle: "Sensitive state hidden",
                    detail: privacyShieldCopy,
                    progress: 0.18,
                    accent: NumiPalette.coral,
                    live: false
                )

                Text("NUMI")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(privacyShieldCopy)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.74))
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .background {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
            .padding(24)
        }
        .ignoresSafeArea()
    }

    private func roleRestriction(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "hand.raised.fill")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(3)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private var rolePill: some View {
        NumiStateBadge(title: model.role.displayName, icon: model.role.isAuthority ? "iphone.gen3" : "ipad.and.arrow.forward", tint: NumiPalette.aqua)
    }

    private var vaultPill: some View {
        NumiStateBadge(title: model.dashboard.isVaultUnlocked ? "Vault Live" : "Vault Sealed", icon: model.dashboard.isVaultUnlocked ? "lock.open.fill" : "lock.fill", tint: NumiPalette.gold)
    }

    private var peerPill: some View {
        NumiStateBadge(title: model.peerPresent ? "Peer Present" : "Awaiting Peer", icon: model.peerPresent ? "dot.radiowaves.left.and.right" : "wave.3.right", tint: NumiPalette.mint)
    }

    private var heroTitle: String {
        if model.role.isAuthority {
            return model.dashboard.isInitialized ? "Authority iPhone" : "Set Up Authority"
        }

        return model.hasRecoveryShare
            ? "\(model.role.displayName) Ready"
            : "Add \(model.role.displayName)"
    }

    private var heroNarrative: String {
        if model.role.isAuthority {
            return "Day visible. Vault sealed."
        }

        return "Recovery and presence only."
    }

    private var heroValue: String {
        if model.role.isAuthority {
            return model.dashboard.isInitialized ? model.dashboard.dayBalance : "Create Root"
        }

        return model.hasRecoveryShare ? "Peer Ready" : "Awaiting Share"
    }

    private var heroCaption: String {
        if model.role.isAuthority {
            return model.dashboard.isVaultUnlocked ? "Vault live for this session" : "Day lane stays visible"
        }

        return model.hasRecoveryShare ? "Peer sealed and ready" : "Awaiting recovery share"
    }

    private var heroIcon: String {
        model.role.isAuthority ? "shield.fill" : "person.badge.key.fill"
    }

    private var heroAccent: Color {
        model.role.isAuthority ? NumiPalette.gold : NumiPalette.aqua
    }

    private var missionStatusTitle: String {
        if model.role.isAuthority {
            return model.dashboard.isInitialized ? "Authority Active" : "Root Missing"
        }

        return model.hasRecoveryShare ? "Peer Bound" : "Peer Unbound"
    }

    private var missionStatusIcon: String {
        if model.role.isAuthority {
            return model.dashboard.isInitialized ? "checkmark.shield.fill" : "shield.slash.fill"
        }

        return model.hasRecoveryShare ? "person.badge.shield.checkmark.fill" : "person.badge.shield.exclamationmark.fill"
    }

    private var missionStatusTint: Color {
        if model.role.isAuthority {
            return model.dashboard.isInitialized ? NumiPalette.mint : NumiPalette.coral
        }

        return model.hasRecoveryShare ? NumiPalette.mint : NumiPalette.gold
    }

    private var privacyPostureTitle: String {
        model.shouldRedactUI ? "Boundary Closed" : "Boundary Private"
    }

    private var sealTitle: String {
        if model.role.isAuthority {
            return model.dashboard.isVaultUnlocked ? "Live Session" : "Policy Ready"
        }

        return model.hasRecoveryShare ? "Peer Sealed" : "Peer Pending"
    }

    private var sealSubtitle: String {
        if model.role.isAuthority {
            return model.dashboard.isVaultUnlocked ? "Vault memory present" : "Trust conditions visible"
        }

        return model.hasRecoveryShare ? "Recovery fragment local" : "Recovery fragment missing"
    }

    private var sealDetail: String {
        if model.role.isAuthority {
            return "Readiness \(Int(sovereigntyReadiness * 100))%"
        }

        return model.hasRecoveryShare ? "This peer can now participate in local recovery." : "Load a fragment to complete this peer."
    }

    private var sovereigntyReadiness: Double {
        if model.role.isAuthority {
            let readiness = [
                model.dashboard.isInitialized ? 0.28 : 0,
                model.peerPresent ? 0.16 : 0,
                0.16 * model.securityPosture.readiness,
                model.supportsPIRStateUpdates ? 0.12 : 0.06,
                model.dashboard.isVaultUnlocked ? 0.16 : 0.08,
                model.supportsShieldedSend ? 0.12 : 0.08
            ].reduce(0, +)

            return min(readiness, 1)
        }

        return model.hasRecoveryShare ? 0.86 : 0.28
    }

    private var heroSignals: [NumiSignal] {
        if model.role.isAuthority {
            return [
                NumiSignal(title: "Day Balance", value: model.dashboard.dayBalance, icon: "sun.max.fill", accent: NumiPalette.aqua, sensitive: true),
                NumiSignal(title: "Vault", value: model.dashboard.vaultBalance ?? hiddenVaultBalanceCopy, icon: "lock.shield.fill", accent: NumiPalette.gold, sensitive: true),
                NumiSignal(title: "Spend Readiness", value: model.dashboard.payReadiness, icon: "arrow.up.forward.circle.fill", accent: NumiPalette.mint)
            ]
        }

        return [
            NumiSignal(title: "Peer Role", value: model.role.displayName, icon: "ipad.and.arrow.forward", accent: NumiPalette.aqua),
            NumiSignal(title: "Fragment", value: model.hasRecoveryShare ? "Present" : "Missing", icon: "person.badge.key.fill", accent: NumiPalette.gold),
            NumiSignal(title: "Privacy", value: model.shouldRedactUI ? "Redacted" : "Sealed", icon: "eye.slash.fill", accent: NumiPalette.coral)
        ]
    }

    private var trustSignals: [NumiSignal] {
        [
            NumiSignal(title: "Bootstrap Code", value: model.pairingCode, icon: "number", accent: NumiPalette.gold),
            NumiSignal(title: "Transport", value: model.pairingTransport, icon: "wave.3.forward.circle.fill", accent: NumiPalette.aqua),
            NumiSignal(title: "Trust Session", value: model.peerTrustSession?.transcriptFingerprint ?? "No active trust session", icon: "checkmark.seal.fill", accent: NumiPalette.mint),
            NumiSignal(title: "Role", value: model.role.displayName, icon: model.role.isAuthority ? "iphone.gen3" : "ipad.landscape", accent: NumiPalette.coral)
        ]
    }

    private var securityPostureSignals: [NumiSignal] {
        let attentionSummary = model.securityPosture.capabilities.isEmpty
            ? "Pending"
            : "\(model.securityPosture.attentionCount) attention • \(model.securityPosture.limitedCount) limited"

        return [
            NumiSignal(title: "Trust Fabric", value: model.securityPosture.shortDescriptor, icon: "lock.shield.fill", accent: NumiPalette.gold),
            NumiSignal(title: "Readiness", value: "\(Int(model.securityPosture.readiness * 100))%", icon: "speedometer", accent: NumiPalette.mint),
            NumiSignal(title: "Preferred Trust", value: model.securityPosture.preferredTrustTransport, icon: "dot.radiowaves.left.and.right", accent: NumiPalette.aqua),
            NumiSignal(title: "Attention", value: attentionSummary, icon: "exclamationmark.shield.fill", accent: NumiPalette.coral)
        ]
    }

    private var trustLedgerSignals: [NumiSignal] {
        let lastRecordedAt = model.trustLedger.lastEventAt?.formatted(date: .abbreviated, time: .shortened) ?? "No history"
        return [
            NumiSignal(title: "Known Peers", value: "\(model.trustLedger.peers.count)", icon: "person.2.fill", accent: NumiPalette.aqua),
            NumiSignal(title: "Active Trust", value: "\(model.trustLedger.activePeerCount)", icon: "checkmark.seal.fill", accent: NumiPalette.mint),
            NumiSignal(title: "Transfer Events", value: "\(model.trustLedger.recentTransferCount)", icon: "tray.and.arrow.up.fill", accent: NumiPalette.gold),
            NumiSignal(title: "Last Audit", value: lastRecordedAt, icon: "clock.badge.checkmark.fill", accent: NumiPalette.coral)
        ]
    }

    private var privacySignals: [NumiSignal] {
        [
            NumiSignal(title: "PIR Status", value: model.dashboard.pirStatus, icon: "eye.slash.fill", accent: NumiPalette.mint),
            NumiSignal(title: "Last Refresh", value: model.dashboard.lastPIRRefresh, icon: "clock.fill", accent: NumiPalette.aqua),
            NumiSignal(title: "Fee Quote", value: model.dashboard.lastFeeQuote, icon: "bitcoinsign.circle.fill", accent: NumiPalette.coral),
            NumiSignal(title: "Tracked Notes", value: "\(model.dashboard.trackedNotes)", icon: "tray.full.fill", accent: NumiPalette.gold),
            NumiSignal(title: "Relationships", value: "\(model.dashboard.trackedTagRelationships)", icon: "person.2.fill", accent: NumiPalette.aqua),
            NumiSignal(title: "Readiness", value: model.dashboard.payReadiness, icon: "paperplane.fill", accent: NumiPalette.mint)
        ]
    }

    private var routeSignals: [NumiSignal] {
        [
            NumiSignal(title: "Peer Trust", value: model.peerTrustStatus, icon: "checkmark.seal.fill", accent: NumiPalette.aqua),
            NumiSignal(title: "PIR Refresh", value: model.dashboard.lastPIRRefresh, icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", accent: NumiPalette.mint),
            NumiSignal(title: "Fee Posture", value: model.dashboard.lastFeeQuote, icon: "bitcoinsign.circle.fill", accent: NumiPalette.coral),
            NumiSignal(title: "Spend Readiness", value: model.dashboard.payReadiness, icon: "arrow.up.forward.circle.fill", accent: NumiPalette.gold)
        ]
    }

    private var ecosystemRoles: [NumiEcosystemRole] {
        [
            NumiEcosystemRole(
                title: "Authority iPhone",
                subtitle: model.dashboard.isInitialized ? "Current root of trust" : "Root still needs ceremony",
                detail: model.dashboard.isVaultUnlocked
                    ? "Day lane active. Vault chamber live now. \(model.securityPosture.shortDescriptor.capitalized)."
                    : "Day lane visible. Vault remains sealed. \(model.securityPosture.shortDescriptor.capitalized).",
                icon: "iphone.gen3",
                accent: NumiPalette.gold,
                readiness: model.dashboard.isInitialized ? min(0.98, 0.52 + (model.securityPosture.readiness * 0.46)) : 0.36
            ),
            NumiEcosystemRole(
                title: "Apple Watch Sentinel",
                subtitle: "Reserved for discreet readiness and seal state",
                detail: model.peerPresent ? "The trust model already values physical presence and fast session sealing." : "Watch role should stay sparse, neutral, and non-financial.",
                icon: "applewatch",
                accent: NumiPalette.mint,
                readiness: 0.42
            ),
            NumiEcosystemRole(
                title: "Recovery iPad",
                subtitle: model.hasRecoveryShare && model.role == .recoveryPad ? "This peer currently holds a fragment" : "Designed as the clearest recovery peer",
                detail: "Large-surface presence approval, recovery drills, and re-enrollment guidance belong here.",
                icon: "ipad.landscape",
                accent: NumiPalette.aqua,
                readiness: model.hasRecoveryShare && model.role == .recoveryPad ? 0.88 : 0.54
            ),
            NumiEcosystemRole(
                title: "Proof Mac",
                subtitle: model.role == .recoveryMac ? "This build is currently running on the Mac peer role" : "Proof lane and diagnostics peer",
                detail: "Advanced proof work, diagnostics, and auditable trust records belong on the Mac without turning it into the authority signer.",
                icon: "macbook.and.iphone",
                accent: NumiPalette.coral,
                readiness: model.role == .recoveryMac ? 0.82 : 0.48
            )
        ]
    }

    private var transitGuidance: [JourneyStep] {
        [
            JourneyStep(
                title: "Resolve a fresh receive intent",
                detail: "Always start from a rotated descriptor rather than a reusable address concept.",
                state: trimmedResolveAlias.isEmpty ? .current : .complete
            ),
            JourneyStep(
                title: "Validate PIR and fee posture",
                detail: "Refresh private state before settlement when readiness or fee confidence is stale.",
                state: model.dashboard.isInitialized ? .complete : .upcoming
            ),
            JourneyStep(
                title: "Choose day or vault deliberately",
                detail: "Use the day lane by default and escalate into the vault only when the payment truly warrants it.",
                state: model.dashboard.isVaultUnlocked ? .live : .upcoming
            )
        ]
    }

    private var hasRecoveryWorkspaceText: Bool {
        !model.recoveryShareText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var trimmedAlias: String {
        model.alias.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedResolveAlias: String {
        model.resolveAlias.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var privacyShieldCopy: String {
        model.isScreenCaptureActive
            ? "Capture boundary active. Sensitive wallet state is hidden."
            : "Sensitive wallet state hidden while inactive."
    }

    private var hiddenVaultBalanceCopy: String {
        model.dashboard.isPrivacyRedacted ? "Redacted" : "Hidden until local auth plus peer quorum"
    }

    @ViewBuilder
    private func immersiveSurfaceView(_ surface: NumiImmersiveSurface) -> some View {
        switch surface {
        case .authorityCeremony:
            NumiAuthorityCeremonyView(
                isInitialized: model.dashboard.isInitialized,
                peerPresent: model.peerPresent,
                peerStatus: model.peerTrustStatus,
                securityPosture: model.securityPosture,
                pairingCode: model.pairingCode,
                statusMessage: model.statusMessage,
                onDismiss: { immersiveSurface = nil },
                onInitialize: {
                    model.initializeAuthorityWallet()
                },
                onRefresh: {
                    model.refreshShieldedState()
                }
            )
        case .vaultChamber:
            NumiVaultChamberView(
                isInitialized: model.dashboard.isInitialized,
                isVaultUnlocked: model.dashboard.isVaultUnlocked,
                peerPresent: model.peerPresent,
                peerStatus: model.peerTrustStatus,
                shouldRedact: model.shouldRedactUI,
                dayBalance: model.dashboard.dayBalance,
                vaultBalance: model.dashboard.vaultBalance ?? hiddenVaultBalanceCopy,
                payReadiness: model.dashboard.payReadiness,
                onDismiss: { immersiveSurface = nil },
                onUnlock: {
                    requestPrivilegedAction(.unlockVault)
                },
                onLock: {
                    model.lockVault()
                }
            )
        case .transitComposer:
            NumiTransitComposerView(
                isAuthority: model.role.isAuthority,
                supportsAliasDiscovery: model.supportsAliasDiscovery,
                supportsShieldedSend: model.supportsShieldedSend,
                isInitialized: model.dashboard.isInitialized,
                isVaultUnlocked: model.dashboard.isVaultUnlocked,
                resolveAlias: $model.resolveAlias,
                sendAmount: $model.sendAmount,
                sendMaximumFee: $model.sendMaximumFee,
                sendMemo: $model.sendMemo,
                resolvedDescriptor: model.resolvedDescriptorFingerprint,
                feeQuote: model.dashboard.lastFeeQuote,
                readiness: model.dashboard.payReadiness,
                onDismiss: { immersiveSurface = nil },
                onResolve: {
                    model.resolveRemoteAlias()
                },
                onSendDay: {
                    requestPrivilegedAction(.sendDayPayment)
                },
                onSendVault: {
                    requestPrivilegedAction(.sendVaultPayment)
                }
            )
        case .recoveryStudio:
            NumiRecoveryStudioView(
                role: model.role,
                isInitialized: model.dashboard.isInitialized,
                hasRecoveryShare: model.hasRecoveryShare,
                workspaceText: $model.recoveryShareText,
                workspaceSummary: model.recoveryWorkspaceSummary,
                statusMessage: model.statusMessage,
                onDismiss: { immersiveSurface = nil },
                onPrepareRecovery: {
                    requestPrivilegedAction(.prepareRecoveryPair)
                },
                onRecoverAuthority: {
                    requestPrivilegedAction(.recoverAuthority)
                },
                onImportShare: {
                    requestPrivilegedAction(.importPeerShare)
                },
                onExportShare: {
                    requestPrivilegedAction(.exportPeerShare)
                }
            )
        case .ecosystemGraph:
            NumiEcosystemGraphView(
                roles: ecosystemRoles,
                onDismiss: { immersiveSurface = nil }
            )
        case .trustLedger:
            NumiTrustLedgerView(
                role: model.role,
                signals: trustLedgerSignals,
                peers: model.trustLedger.peers,
                events: model.trustLedger.events,
                onDismiss: { immersiveSurface = nil }
            )
        }
    }

    private func requestPrivilegedAction(_ action: NumiPrivilegedAction) {
        privilegedAction = action
    }

    @ViewBuilder
    private func withPrivilegedAuthentication<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .numiModal(item: $privilegedAction) { action in
                NumiPrivilegedAuthenticationView(
                    action: action,
                    onCancel: {
                        privilegedAction = nil
                    },
                    onAuthorize: { context in
                        privilegedAction = nil
                        executePrivilegedAction(action, authorizationContext: context)
                    }
                )
                .preferredColorScheme(.dark)
            }
    }

    private func executePrivilegedAction(_ action: NumiPrivilegedAction, authorizationContext: LAContext) {
        switch action {
        case .unlockVault:
            model.unlockVault(authorizationContext: authorizationContext)
        case .sendDayPayment:
            model.sendDemoPayment(from: .day, authorizationContext: authorizationContext)
        case .sendVaultPayment:
            model.sendDemoPayment(from: .vault, authorizationContext: authorizationContext)
        case .prepareRecoveryPair:
            model.configureRecoveryPeers(authorizationContext: authorizationContext)
        case .recoverAuthority:
            model.recoverAuthorityFromBundle(authorizationContext: authorizationContext)
        case .importPeerShare:
            model.importRecoveryShare(authorizationContext: authorizationContext)
        case .exportPeerShare:
            model.exportRecoveryShare(authorizationContext: authorizationContext)
        case .panicWipe:
            model.panicWipe(authorizationContext: authorizationContext)
        }
    }

    private func playFeedback(for event: WalletExperienceEvent?) {
        #if canImport(UIKit)
        guard let event else { return }
        switch event.feedbackStyle {
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
        #endif
    }

    private func bottomCommandDock(contentMaxWidth: CGFloat, isCompact: Bool) -> some View {
        let tabColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: DashboardDeck.allCases.count)

        return VStack(spacing: isCompact ? 10 : 12) {
            LazyVGrid(columns: tabColumns, spacing: 10) {
                ForEach(DashboardDeck.allCases) { deck in
                    Button {
                        selectedDeck = deck
                    } label: {
                        NumiDockTab(deck: deck, selected: selectedDeck == deck)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: performPrimaryDockAction) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.26))
                        Image(systemName: primaryDockIcon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(NumiPalette.ink)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryDockTitle)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(NumiPalette.ink)
                        Text(primaryDockSubtitle)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(NumiPalette.ink.opacity(0.72))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(NumiPalette.ink.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryDockAccent.opacity(0.92),
                                    Color.white.opacity(0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!primaryDockEnabled)
            .opacity(primaryDockEnabled ? 1 : 0.44)
        }
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, isCompact ? 16 : 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
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

    private var primaryDockTitle: String {
        switch selectedDeck {
        case .wallet:
            if model.role.isAuthority {
                return model.dashboard.isInitialized ? "Enter Vault Chamber" : "Begin Authority Ceremony"
            }
            return model.hasRecoveryShare ? "Export Peer Share" : "Import Peer Share"
        case .transit:
            if model.role.isAuthority {
                return "Open Composer"
            }
            return "Open Peer View"
        case .custody:
            if model.role.isAuthority {
                return "Open Recovery Studio"
            }
            return "Open Recovery Studio"
        }
    }

    private var primaryDockSubtitle: String {
        switch selectedDeck {
        case .wallet:
            if model.role.isAuthority {
                return model.dashboard.isInitialized
                    ? "Open the immersive vault surface with explicit policy checks"
                    : "Present the first-run authority sequence full screen"
            }
            return model.hasRecoveryShare
                ? "Open the focused peer custody surface"
                : "Open the focused peer custody surface"
        case .transit:
            if model.role.isAuthority {
                return "Compose settlement without inline clutter"
            }
            return "Inspect the authority-only transit boundary"
        case .custody:
            if model.role.isAuthority {
                return "Move fragment staging and recovery actions full screen"
            }
            return "Move fragment staging and recovery actions full screen"
        }
    }

    private var primaryDockIcon: String {
        switch selectedDeck {
        case .wallet:
            if model.role.isAuthority {
                return model.dashboard.isInitialized ? "lock.open.fill" : "sparkles"
            }
            return model.hasRecoveryShare ? "square.and.arrow.up.fill" : "square.and.arrow.down.fill"
        case .transit:
            if model.role.isAuthority {
                return "paperplane.circle.fill"
            }
            return "hand.raised.fill"
        case .custody:
            return "person.crop.rectangle.stack.fill"
        }
    }

    private var primaryDockAccent: Color {
        switch selectedDeck {
        case .wallet:
            return NumiPalette.gold
        case .transit:
            return NumiPalette.coral
        case .custody:
            return NumiPalette.aqua
        }
    }

    private var primaryDockEnabled: Bool {
        switch selectedDeck {
        case .wallet:
            if model.role.isAuthority {
                return true
            }
            return true
        case .transit:
            return true
        case .custody:
            return true
        }
    }

    private func performPrimaryDockAction() {
        guard primaryDockEnabled else { return }

        switch selectedDeck {
        case .wallet:
            if model.role.isAuthority {
                immersiveSurface = model.dashboard.isInitialized ? .vaultChamber : .authorityCeremony
            } else {
                immersiveSurface = .recoveryStudio
            }
        case .transit:
            immersiveSurface = .transitComposer
        case .custody:
            immersiveSurface = .recoveryStudio
        }
    }
}

private extension View {
    @ViewBuilder
    func numiModal<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, content: content)
        #else
        fullScreenCover(item: item, content: content)
        #endif
    }
}

enum DashboardDeck: String, CaseIterable, Identifiable {
    case wallet
    case transit
    case custody

    var id: String { rawValue }

    static func defaultDeck(for role: DeviceRole) -> DashboardDeck {
        switch role {
        case .authorityPhone:
            return .wallet
        case .recoveryPad:
            return .custody
        case .recoveryMac:
            return .wallet
        }
    }

    var title: String {
        switch self {
        case .wallet:
            return "Wallet"
        case .transit:
            return "Transit"
        case .custody:
            return "Custody"
        }
    }

    var icon: String {
        switch self {
        case .wallet:
            return "wallet.pass.fill"
        case .transit:
            return "paperplane.circle.fill"
        case .custody:
            return "lock.rectangle.stack.fill"
        }
    }

    var accent: Color {
        switch self {
        case .wallet:
            return NumiPalette.gold
        case .transit:
            return NumiPalette.coral
        case .custody:
            return NumiPalette.aqua
        }
    }
}

private struct NumiMacConsoleMetrics {
    let width: CGFloat
    let contentMaxWidth: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let columnSpacing: CGFloat
    let usesTwoColumns: Bool
    let sideColumnWidth: CGFloat
    let sealSize: CGFloat

    init(width: CGFloat) {
        self.width = width
        usesTwoColumns = width >= 1120

        if width >= 1640 {
            contentMaxWidth = 1400
        } else if width >= 1360 {
            contentMaxWidth = 1280
        } else {
            contentMaxWidth = .infinity
        }

        horizontalPadding = width < 900 ? 20 : 28
        topPadding = width < 900 ? 18 : 24
        bottomPadding = width < 900 ? 24 : 32
        sectionSpacing = width < 900 ? 18 : 20
        columnSpacing = width < 900 ? 18 : 20
        sideColumnWidth = width >= 1440 ? 392 : 364
        sealSize = width < 980 ? 152 : 176
    }
}

struct NumiMacConsoleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: WalletAppModel
    @State private var immersiveSurface: NumiImmersiveSurface?
    @State private var privilegedAction: NumiPrivilegedAction?

    var body: some View {
        withPrivilegedAuthentication {
            GeometryReader { geometry in
                let metrics = NumiMacConsoleMetrics(width: geometry.size.width)

                ZStack {
                    NumiMacBackdrop()

                    ScrollView {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            consoleHeader(metrics: metrics)

                            if metrics.usesTwoColumns {
                                HStack(alignment: .top, spacing: metrics.columnSpacing) {
                                    leftColumn(metrics: metrics)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    rightColumn
                                        .frame(width: metrics.sideColumnWidth, alignment: .top)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                                    leftColumn(metrics: metrics)
                                    rightColumn
                                }
                            }
                        }
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.topPadding)
                        .padding(.bottom, metrics.bottomPadding)
                    }
                    .scrollIndicators(.hidden)
                    .task {
                        model.start()
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        model.handleScenePhase(newPhase)
                    }

                    if scenePhase != .active || model.shouldRedactUI {
                        macPrivacyShield
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.88), value: model.latestEvent?.id)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.88), value: model.peerPresent)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.88), value: model.hasRecoveryShare)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.88), value: model.shouldRedactUI)
        .numiModal(item: $immersiveSurface) { surface in
            immersiveSurfaceView(surface)
        }
    }

    private func consoleHeader(metrics: NumiMacConsoleMetrics) -> some View {
        NumiMacGlassPanel(
            eyebrow: "Recovery Mac",
            title: model.peerPresent ? "Trusted peer workstation is live" : "Mac stays ready without becoming the signer",
            subtitle: "Proof, recovery approval, and diagnostics belong here. Spend authority and long-lived secrets do not.",
            accent: consoleAccent
        ) {
            ViewThatFits {
                HStack(alignment: .center, spacing: 28) {
                    headerNarrative
                    Spacer(minLength: 0)
                    consoleSeal(size: metrics.sealSize)
                }

                VStack(alignment: .leading, spacing: 18) {
                    headerNarrative
                    HStack {
                        Spacer(minLength: 0)
                        consoleSeal(size: metrics.sealSize)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var headerNarrative: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(consoleNarrative)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits {
                HStack(spacing: 10) {
                    ForEach(consoleChips) { chip in
                        NumiMacStateChip(title: chip.title, icon: chip.icon, tint: chip.tint)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(consoleChips) { chip in
                        NumiMacStateChip(title: chip.title, icon: chip.icon, tint: chip.tint)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 188, maximum: 260), spacing: 10)], spacing: 10) {
                NumiMacCommandButton(
                    title: "Recovery Studio",
                    subtitle: "Inspect or stage bounded fragment work.",
                    icon: "person.crop.rectangle.stack.fill",
                    accent: NumiPalette.aqua
                ) {
                    immersiveSurface = .recoveryStudio
                }

                NumiMacCommandButton(
                    title: "Trust Ledger",
                    subtitle: "Review paired devices and recent local trust events.",
                    icon: "list.clipboard.fill",
                    accent: NumiPalette.gold
                ) {
                    immersiveSurface = .trustLedger
                }

                NumiMacCommandButton(
                    title: "Apple Roles",
                    subtitle: "Inspect the cross-device topology and role posture.",
                    icon: "apple.logo",
                    accent: NumiPalette.mint
                ) {
                    immersiveSurface = .ecosystemGraph
                }
            }
        }
    }

    private func consoleSeal(size: CGFloat) -> some View {
        NumiChamberSeal(
            title: model.peerPresent ? "Trusted" : "Standby",
            subtitle: model.peerPresent ? "Peer lane active" : "Awaiting authority",
            detail: "Readiness \(Int(consoleReadiness * 100))%",
            progress: consoleReadiness,
            accent: consoleAccent,
            live: model.peerPresent && !model.shouldRedactUI,
            size: size
        )
    }

    private func leftColumn(metrics: NumiMacConsoleMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            proofLanePanel
            recentActivityPanel
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            peerConsolePanel
            recoveryPanel
            diagnosticsPanel
        }
    }

    private var proofLanePanel: some View {
        NumiMacGlassPanel(
            eyebrow: "Proof Lane",
            title: "Bounded compute, explicit transit posture",
            subtitle: "Mac reveals readiness, venue, and evidence without turning into a balance-forward dashboard.",
            accent: NumiPalette.aqua
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("This lane should explain whether proof work, private-state freshness, and settlement posture are healthy enough to proceed, while keeping spend authority elsewhere.")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))

                NumiMacMetricGrid(metrics: proofMetrics)

                NumiMacCommandButton(
                    title: "Inspect Transit Boundary",
                    subtitle: "Open the non-authority transit surface for context.",
                    icon: "paperplane.circle.fill",
                    accent: NumiPalette.coral
                ) {
                    immersiveSurface = .transitComposer
                }
            }
        }
    }

    private var peerConsolePanel: some View {
        NumiMacGlassPanel(
            eyebrow: "Peer Console",
            title: peerPanelTitle,
            subtitle: "Trust should feel short-lived, named, and mechanically obvious.",
            accent: peerAccent
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if model.peerPresent {
                    NumiMacMetricGrid(metrics: activePeerMetrics)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Bootstrap Code")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(peerAccent)

                        Text(model.pairingCode)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .privacySensitive()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(peerAccent.opacity(0.22), lineWidth: 1)
                                    }
                            }

                        NumiMacMetricGrid(metrics: idlePeerMetrics)
                    }
                }
            }
        }
    }

    private var recoveryPanel: some View {
        NumiMacGlassPanel(
            eyebrow: "Recovery Readiness",
            title: recoveryPanelTitle,
            subtitle: "Fragment custody should remain explicit, local, and approval-driven.",
            accent: recoveryAccent
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.recoveryWorkspaceSummary.recommendation)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                NumiMacMetricGrid(metrics: recoveryMetrics)

                NumiMacCommandButton(
                    title: "Open Recovery Studio",
                    subtitle: model.hasRecoveryShare ? "Review or export the sealed peer share." : "Import or stage recovery material on this Mac.",
                    icon: "person.crop.rectangle.stack.fill",
                    accent: NumiPalette.aqua
                ) {
                    immersiveSurface = .recoveryStudio
                }
            }
        }
    }

    private var diagnosticsPanel: some View {
        NumiMacGlassPanel(
            eyebrow: "Diagnostics",
            title: model.securityPosture.headline,
            subtitle: model.securityPosture.summary,
            accent: diagnosticsAccent
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits {
                    HStack(spacing: 10) {
                        ForEach(diagnosticChips) { chip in
                            NumiMacStateChip(title: chip.title, icon: chip.icon, tint: chip.tint)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(diagnosticChips) { chip in
                            NumiMacStateChip(title: chip.title, icon: chip.icon, tint: chip.tint)
                        }
                    }
                }

                if model.securityPosture.capabilities.isEmpty {
                    Text("Capability telemetry is still loading. Once complete, this console should explain which Apple trust anchors are ready, constrained, or degraded.")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(model.securityPosture.capabilities) { capability in
                            NumiMacCapabilityRow(capability: capability)
                        }
                    }
                }
            }
        }
    }

    private var recentActivityPanel: some View {
        NumiMacGlassPanel(
            eyebrow: "Local Audit",
            title: "One quiet lane for meaningful events",
            subtitle: "Desktop gets more evidence, not more noise.",
            accent: NumiPalette.coral
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let latest = model.latestEvent {
                    NumiEventRow(event: latest, prominent: true)
                } else {
                    Text(model.statusMessage)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .privacySensitive()
                }

                ForEach(recentAuditEvents) { event in
                    NumiEventRow(event: event, prominent: false)
                }
            }
        }
    }

    private var macPrivacyShield: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.42))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                NumiChamberSeal(
                    title: "Redacted",
                    subtitle: "Peer workstation sealed",
                    detail: model.isScreenCaptureActive ? "Capture boundary active" : "Foreground trust boundary closed",
                    progress: 0.18,
                    accent: NumiPalette.coral,
                    live: false,
                    size: 142
                )

                Text("Sensitive state hidden")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text(model.isScreenCaptureActive
                    ? "Numi cleared local sensitive state because a capture boundary was detected."
                    : "Numi sealed this workstation while it was inactive or otherwise outside a safe privacy boundary.")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .background {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
            .padding(24)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func immersiveSurfaceView(_ surface: NumiImmersiveSurface) -> some View {
        switch surface {
        case .transitComposer:
            NumiTransitComposerView(
                isAuthority: model.role.isAuthority,
                supportsAliasDiscovery: model.supportsAliasDiscovery,
                supportsShieldedSend: model.supportsShieldedSend,
                isInitialized: model.dashboard.isInitialized,
                isVaultUnlocked: model.dashboard.isVaultUnlocked,
                resolveAlias: $model.resolveAlias,
                sendAmount: $model.sendAmount,
                sendMaximumFee: $model.sendMaximumFee,
                sendMemo: $model.sendMemo,
                resolvedDescriptor: model.resolvedDescriptorFingerprint,
                feeQuote: model.dashboard.lastFeeQuote,
                readiness: model.dashboard.payReadiness,
                onDismiss: { immersiveSurface = nil },
                onResolve: {
                    model.resolveRemoteAlias()
                },
                onSendDay: {
                    requestPrivilegedAction(.sendDayPayment)
                },
                onSendVault: {
                    requestPrivilegedAction(.sendVaultPayment)
                }
            )
        case .recoveryStudio:
            NumiRecoveryStudioView(
                role: model.role,
                isInitialized: model.dashboard.isInitialized,
                hasRecoveryShare: model.hasRecoveryShare,
                workspaceText: $model.recoveryShareText,
                workspaceSummary: model.recoveryWorkspaceSummary,
                statusMessage: model.statusMessage,
                onDismiss: { immersiveSurface = nil },
                onPrepareRecovery: {
                    requestPrivilegedAction(.prepareRecoveryPair)
                },
                onRecoverAuthority: {
                    requestPrivilegedAction(.recoverAuthority)
                },
                onImportShare: {
                    requestPrivilegedAction(.importPeerShare)
                },
                onExportShare: {
                    requestPrivilegedAction(.exportPeerShare)
                }
            )
        case .ecosystemGraph:
            NumiEcosystemGraphView(
                roles: ecosystemRoles,
                onDismiss: { immersiveSurface = nil }
            )
        case .trustLedger:
            NumiTrustLedgerView(
                role: model.role,
                signals: trustLedgerSignals,
                peers: model.trustLedger.peers,
                events: model.trustLedger.events,
                onDismiss: { immersiveSurface = nil }
            )
        case .authorityCeremony, .vaultChamber:
            EmptyView()
        }
    }

    private func requestPrivilegedAction(_ action: NumiPrivilegedAction) {
        privilegedAction = action
    }

    @ViewBuilder
    private func withPrivilegedAuthentication<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .numiModal(item: $privilegedAction) { action in
                NumiPrivilegedAuthenticationView(
                    action: action,
                    onCancel: {
                        privilegedAction = nil
                    },
                    onAuthorize: { context in
                        privilegedAction = nil
                        executePrivilegedAction(action, authorizationContext: context)
                    }
                )
                .preferredColorScheme(.dark)
            }
    }

    private func executePrivilegedAction(_ action: NumiPrivilegedAction, authorizationContext: LAContext) {
        switch action {
        case .unlockVault:
            model.unlockVault(authorizationContext: authorizationContext)
        case .sendDayPayment:
            model.sendDemoPayment(from: .day, authorizationContext: authorizationContext)
        case .sendVaultPayment:
            model.sendDemoPayment(from: .vault, authorizationContext: authorizationContext)
        case .prepareRecoveryPair:
            model.configureRecoveryPeers(authorizationContext: authorizationContext)
        case .recoverAuthority:
            model.recoverAuthorityFromBundle(authorizationContext: authorizationContext)
        case .importPeerShare:
            model.importRecoveryShare(authorizationContext: authorizationContext)
        case .exportPeerShare:
            model.exportRecoveryShare(authorizationContext: authorizationContext)
        case .panicWipe:
            model.panicWipe(authorizationContext: authorizationContext)
        }
    }

    private var consoleNarrative: String {
        if let session = model.peerTrustSession, session.isActive {
            return "\(session.peerName) is currently trusted for local recovery and diagnostics. The Mac stays visibly useful while the authority root remains on the iPhone."
        }

        return "This workstation is for proof posture, recovery approval, and auditable trust state. It should feel deliberate, sparse, and obviously incapable of becoming the authority wallet."
    }

    private var consoleReadiness: Double {
        let readiness = [
            0.5 * model.securityPosture.readiness,
            model.peerPresent ? 0.24 : 0.08,
            model.hasRecoveryShare ? 0.16 : 0.08,
            model.shouldRedactUI ? 0.02 : 0.12
        ].reduce(0, +)

        return min(readiness, 1)
    }

    private var consoleAccent: Color {
        if model.shouldRedactUI {
            return NumiPalette.coral
        }

        return model.peerPresent ? NumiPalette.mint : NumiPalette.gold
    }

    private var peerAccent: Color {
        guard let session = model.peerTrustSession, session.isActive else { return NumiPalette.gold }
        switch session.trustLevel {
        case .attestedLocal:
            return NumiPalette.gold
        case .nearbyVerified:
            return NumiPalette.mint
        }
    }

    private var recoveryAccent: Color {
        switch model.recoveryWorkspaceSummary.tone {
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

    private var diagnosticsAccent: Color {
        if model.securityPosture.limitedCount > 0 {
            return NumiPalette.coral
        }
        if model.securityPosture.attentionCount > 0 {
            return NumiPalette.gold
        }
        return NumiPalette.mint
    }

    private var peerPanelTitle: String {
        if let session = model.peerTrustSession, session.isActive {
            return "\(session.peerName) is trusted via \(session.transportLabel)"
        }

        return "Authority pairing stays visible before it becomes active"
    }

    private var recoveryPanelTitle: String {
        if model.hasRecoveryShare {
            return "Local fragment is sealed on this Mac"
        }

        return "This Mac can approve recovery without holding wallet authority"
    }

    private var consoleChips: [NumiMacChip] {
        [
            NumiMacChip(title: "No Signing Authority", icon: "lock.slash.fill", tint: NumiPalette.gold),
            NumiMacChip(title: model.peerPresent ? "Peer Present" : "Awaiting Peer", icon: model.peerPresent ? "dot.radiowaves.left.and.right" : "wave.3.right", tint: model.peerPresent ? NumiPalette.mint : NumiPalette.gold),
            NumiMacChip(title: model.hasRecoveryShare ? "Fragment Local" : "No Local Fragment", icon: model.hasRecoveryShare ? "checkmark.shield.fill" : "square.dashed", tint: model.hasRecoveryShare ? NumiPalette.aqua : Color.white.opacity(0.5)),
            NumiMacChip(title: model.shouldRedactUI ? "Privacy Closed" : "Privacy Clear", icon: "eye.slash.fill", tint: model.shouldRedactUI ? NumiPalette.coral : NumiPalette.aqua)
        ]
    }

    private var diagnosticChips: [NumiMacChip] {
        [
            NumiMacChip(title: "\(model.securityPosture.readyCount) Ready", icon: "checkmark.circle.fill", tint: NumiPalette.mint),
            NumiMacChip(title: "\(model.securityPosture.attentionCount) Attention", icon: "exclamationmark.circle.fill", tint: NumiPalette.gold),
            NumiMacChip(title: "\(model.securityPosture.limitedCount) Limited", icon: "xmark.circle.fill", tint: NumiPalette.coral)
        ]
    }

    private var proofMetrics: [NumiMacMetric] {
        [
            NumiMacMetric(label: "Proof Venue", value: model.dashboard.proofVenue, icon: "cpu.fill", tint: NumiPalette.aqua),
            NumiMacMetric(label: "Spend Readiness", value: model.dashboard.payReadiness, icon: "arrow.up.forward.circle.fill", tint: NumiPalette.mint),
            NumiMacMetric(label: "Last PIR Refresh", value: model.dashboard.lastPIRRefresh, icon: "clock.arrow.circlepath", tint: NumiPalette.gold),
            NumiMacMetric(label: "Fee Posture", value: model.dashboard.lastFeeQuote, icon: "bitcoinsign.circle.fill", tint: NumiPalette.coral)
        ]
    }

    private var activePeerMetrics: [NumiMacMetric] {
        guard let session = model.peerTrustSession else {
            return idlePeerMetrics
        }

        return [
            NumiMacMetric(label: "Peer", value: session.peerName, icon: "person.crop.circle.fill", tint: peerAccent),
            NumiMacMetric(label: "Trust", value: session.stateLabel, icon: "checkmark.seal.fill", tint: peerAccent),
            NumiMacMetric(label: "Transport", value: session.transportLabel, icon: "wave.3.forward.circle.fill", tint: NumiPalette.aqua),
            NumiMacMetric(label: "Expires", value: session.expiresAt.formatted(date: .omitted, time: .shortened), icon: "clock.badge.checkmark.fill", tint: NumiPalette.gold),
            NumiMacMetric(label: "Fingerprint", value: session.transcriptFingerprint, icon: "number", tint: NumiPalette.mint),
            NumiMacMetric(label: "Known Peers", value: "\(model.trustLedger.peers.count)", icon: "person.2.fill", tint: NumiPalette.aqua)
        ]
    }

    private var idlePeerMetrics: [NumiMacMetric] {
        [
            NumiMacMetric(label: "Transport", value: model.pairingTransport, icon: "wave.3.forward.circle.fill", tint: NumiPalette.aqua),
            NumiMacMetric(label: "Session Transcript", value: model.pairingSessionFingerprint, icon: "number", tint: NumiPalette.mint),
            NumiMacMetric(label: "Known Peers", value: "\(model.trustLedger.peers.count)", icon: "person.2.fill", tint: NumiPalette.gold),
            NumiMacMetric(label: "Last Audit", value: model.trustLedger.lastEventAt?.formatted(date: .abbreviated, time: .shortened) ?? "No history", icon: "clock.badge.checkmark.fill", tint: NumiPalette.coral)
        ]
    }

    private var recoveryMetrics: [NumiMacMetric] {
        let summary = model.recoveryWorkspaceSummary
        return [
            NumiMacMetric(label: "Workspace", value: summary.title, icon: summary.systemImage, tint: recoveryAccent),
            NumiMacMetric(label: "Local Share", value: model.hasRecoveryShare ? "Present" : "Missing", icon: model.hasRecoveryShare ? "checkmark.shield.fill" : "square.dashed", tint: model.hasRecoveryShare ? NumiPalette.mint : NumiPalette.gold),
            NumiMacMetric(label: "Transfer Events", value: "\(model.trustLedger.recentTransferCount)", icon: "tray.and.arrow.up.fill", tint: NumiPalette.aqua),
            NumiMacMetric(label: "Authority Path", value: summary.canRecoverAuthority ? "Recovery bundle ready" : "Awaiting explicit bundle", icon: "iphone.gen3", tint: summary.canRecoverAuthority ? NumiPalette.mint : NumiPalette.gold)
        ]
    }

    private var recentAuditEvents: [WalletExperienceEvent] {
        let recent = model.recentEvents

        guard let latest = model.latestEvent else {
            return Array(recent.prefix(5))
        }

        if recent.first?.id == latest.id {
            return Array(recent.dropFirst().prefix(4))
        }

        return Array(recent.prefix(4))
    }

    private var trustLedgerSignals: [NumiSignal] {
        let lastRecordedAt = model.trustLedger.lastEventAt?.formatted(date: .abbreviated, time: .shortened) ?? "No history"
        return [
            NumiSignal(title: "Known Peers", value: "\(model.trustLedger.peers.count)", icon: "person.2.fill", accent: NumiPalette.aqua),
            NumiSignal(title: "Active Trust", value: "\(model.trustLedger.activePeerCount)", icon: "checkmark.seal.fill", accent: NumiPalette.mint),
            NumiSignal(title: "Transfer Events", value: "\(model.trustLedger.recentTransferCount)", icon: "tray.and.arrow.up.fill", accent: NumiPalette.gold),
            NumiSignal(title: "Last Audit", value: lastRecordedAt, icon: "clock.badge.checkmark.fill", accent: NumiPalette.coral)
        ]
    }

    private var ecosystemRoles: [NumiEcosystemRole] {
        [
            NumiEcosystemRole(
                title: "Authority iPhone",
                subtitle: model.dashboard.isInitialized ? "Current root of trust" : "Root still needs ceremony",
                detail: model.dashboard.isVaultUnlocked
                    ? "Day lane active. Vault chamber live now. \(model.securityPosture.shortDescriptor.capitalized)."
                    : "Day lane visible. Vault remains sealed. \(model.securityPosture.shortDescriptor.capitalized).",
                icon: "iphone.gen3",
                accent: NumiPalette.gold,
                readiness: model.dashboard.isInitialized ? min(0.98, 0.52 + (model.securityPosture.readiness * 0.46)) : 0.36
            ),
            NumiEcosystemRole(
                title: "Apple Watch Sentinel",
                subtitle: "Reserved for discreet readiness and seal state",
                detail: model.peerPresent ? "The trust model already values physical presence and fast session sealing." : "Watch role should stay sparse, neutral, and non-financial.",
                icon: "applewatch",
                accent: NumiPalette.mint,
                readiness: 0.42
            ),
            NumiEcosystemRole(
                title: "Recovery iPad",
                subtitle: model.hasRecoveryShare && model.role == .recoveryPad ? "This peer currently holds a fragment" : "Designed as the clearest recovery peer",
                detail: "Large-surface presence approval, recovery drills, and re-enrollment guidance belong here.",
                icon: "ipad.landscape",
                accent: NumiPalette.aqua,
                readiness: model.hasRecoveryShare && model.role == .recoveryPad ? 0.88 : 0.54
            ),
            NumiEcosystemRole(
                title: "Proof Mac",
                subtitle: model.role == .recoveryMac ? "This build is currently running on the Mac peer role" : "Proof lane and diagnostics peer",
                detail: "Advanced proof work, diagnostics, and auditable trust records belong on the Mac without turning it into the authority signer.",
                icon: "macbook.and.iphone",
                accent: NumiPalette.coral,
                readiness: model.role == .recoveryMac ? 0.82 : 0.48
            )
        ]
    }
}

private struct NumiMacBackdrop: View {
    var body: some View {
        NumiBackdrop()
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.26),
                        Color.black.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
    }
}

private struct NumiMacGlassPanel<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder var content: Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.regularMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16),
                                    accent.opacity(0.18),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: Color.black.opacity(0.24), radius: 26, x: 0, y: 16)
    }
}

private struct NumiMacChip: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
}

private struct NumiMacStateChip: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.32), lineWidth: 1)
                    }
            }
    }
}

private struct NumiMacCommandButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.18))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(accent.opacity(0.24), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct NumiMacMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
    let tint: Color
}

private struct NumiMacMetricGrid: View {
    let metrics: [NumiMacMetric]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 154, maximum: 260), spacing: 10)], spacing: 10) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 10) {
                    Label(metric.label, systemImage: metric.icon)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(metric.tint)

                    Text(metric.value)
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(metric.tint.opacity(0.18), lineWidth: 1)
                        }
                }
            }
        }
    }
}

private struct NumiMacCapabilityRow: View {
    let capability: AppleSecurityCapability

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
                Image(systemName: capability.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(capability.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    Text(capability.shortValue)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(tint)
                }

                Text(capability.detail)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                Text(capability.recommendation)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private var tint: Color {
        switch capability.state {
        case .ready:
            return NumiPalette.mint
        case .attention:
            return NumiPalette.gold
        case .limited:
            return NumiPalette.coral
        }
    }
}

enum NumiPalette {
    static let ink = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let night = Color(red: 0.10, green: 0.13, blue: 0.18)
    static let steel = Color(red: 0.18, green: 0.21, blue: 0.28)
    static let gold = Color(red: 0.93, green: 0.78, blue: 0.56)
    static let aqua = Color(red: 0.63, green: 0.84, blue: 0.95)
    static let mint = Color(red: 0.61, green: 0.90, blue: 0.79)
    static let coral = Color(red: 0.98, green: 0.58, blue: 0.52)
}

private struct NumiSignal: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let accent: Color
    var sensitive = false
}

private struct JourneyStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: JourneyStepState
}

private enum JourneyStepState {
    case complete
    case current
    case live
    case upcoming

    var icon: String {
        switch self {
        case .complete:
            return "checkmark.circle.fill"
        case .current:
            return "circle.lefthalf.filled"
        case .live:
            return "waveform.path.ecg.circle.fill"
        case .upcoming:
            return "circle"
        }
    }

    var tint: Color {
        switch self {
        case .complete:
            return NumiPalette.mint
        case .current:
            return NumiPalette.gold
        case .live:
            return NumiPalette.aqua
        case .upcoming:
            return Color.white.opacity(0.34)
        }
    }
}

private struct NumiBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let aquaPanelSize = min(max(width * 1.1, 320), 520)
            let goldGlowSize = min(max(width * 0.9, 260), 420)
            let aquaGlowSize = min(max(width, 320), 460)
            let coralGlowSize = min(max(width * 0.62, 180), 280)

            ZStack {
                LinearGradient(
                    colors: [
                        NumiPalette.ink,
                        NumiPalette.night,
                        Color(red: 0.15, green: 0.16, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: aquaPanelSize, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [NumiPalette.aqua.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: aquaPanelSize, height: aquaPanelSize)
                    .offset(x: -width * 0.34, y: -width * 0.56)
                    .blur(radius: 36)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NumiPalette.gold.opacity(0.44), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: goldGlowSize * 0.58
                        )
                    )
                    .frame(width: goldGlowSize, height: goldGlowSize)
                    .offset(x: -width * 0.3, y: -width * 0.56)
                    .blur(radius: 28)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NumiPalette.aqua.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: aquaGlowSize * 0.57
                        )
                    )
                    .frame(width: aquaGlowSize, height: aquaGlowSize)
                    .offset(x: width * 0.38, y: width * 0.46)
                    .blur(radius: 40)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NumiPalette.coral.opacity(0.20), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: coralGlowSize * 0.64
                        )
                    )
                    .frame(width: coralGlowSize, height: coralGlowSize)
                    .offset(x: width * 0.34, y: -width * 0.3)
                    .blur(radius: 28)
            }
        }
        .ignoresSafeArea()
    }
}

private struct NumiGlassPanel<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    @ViewBuilder var content: Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        let isCompact = horizontalSizeClass == .compact
        let panelPadding: CGFloat = isCompact ? 18 : 22
        let cornerRadius: CGFloat = isCompact ? 28 : 32

        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits {
                HStack(alignment: .top, spacing: 14) {
                    panelIconBadge(size: isCompact ? 40 : 44)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(eyebrow.uppercased())
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(accent)
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .lineLimit(2)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    panelIconBadge(size: isCompact ? 40 : 44)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(eyebrow.uppercased())
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(accent)
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .lineLimit(2)
                    }
                }
            }

            content
        }
        .padding(panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    accent.opacity(0.22),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: accent.opacity(0.14), radius: 28, x: 0, y: 18)
    }

    private func panelIconBadge(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.18))
            Circle()
                .strokeBorder(accent.opacity(0.68), lineWidth: 1)

            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

private struct NumiChamberSeal: View {
    let title: String
    let subtitle: String
    let detail: String
    let progress: Double
    let accent: Color
    let live: Bool
    var size: CGFloat = 208

    private var ringLineWidth: CGFloat { max(12, size * 0.086) }
    private var innerPadding: CGFloat { max(22, size * 0.144) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: ringLineWidth)

            Circle()
                .trim(from: 0, to: max(0.06, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        colors: [accent, Color.white.opacity(0.95), accent.opacity(0.66)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .stroke(accent.opacity(live ? 0.65 : 0.18), lineWidth: 1)
                .padding(innerPadding)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: size < 180 ? 15 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(accent)
                Text(detail)
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct NumiStateBadge: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.46), lineWidth: 1)
                    }
            }
    }
}

private struct NumiDeckChip: View {
    let deck: DashboardDeck
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: deck.icon)
                .font(.system(size: 14, weight: .bold))
            Text(deck.title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            Capsule(style: .continuous)
                .fill(selected ? deck.accent.opacity(0.22) : Color.white.opacity(0.05))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(selected ? deck.accent.opacity(0.74) : Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiDockTab: View {
    let deck: DashboardDeck
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: deck.icon)
                .font(.system(size: 15, weight: .bold))
            Text(deck.title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selected ? deck.accent.opacity(0.24) : Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(selected ? deck.accent.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiSignalTile: View {
    let signal: NumiSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(signal.title, systemImage: signal.icon)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(signal.accent)

            Text(signal.value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .privacySensitive(signal.sensitive)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiCompartmentCard: View {
    let title: String
    let tone: String
    let balance: String
    let state: String
    let accent: Color
    let icon: String
    let sensitive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.16))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(tone)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(accent)
                }
            }

            Text(balance)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)
                .privacySensitive(sensitive)

            Text(state)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private struct NumiFeatureButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(enabled ? accent.opacity(0.22) : Color.white.opacity(0.05))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(enabled ? .white : Color.white.opacity(0.34))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(enabled ? .white : Color.white.opacity(0.42))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(enabled ? Color.white.opacity(0.64) : Color.white.opacity(0.34))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(enabled ? Color.white.opacity(0.075) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(enabled ? accent.opacity(0.38) : Color.white.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct NumiTimelineRow: View {
    let step: JourneyStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.state.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(step.state.tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(step.detail)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct NumiInputField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.62))

            field
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

    private var field: some View {
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
    }
}

private struct NumiWorkspaceSummaryCard: View {
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
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(2)

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
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

private struct NumiPeerTrustCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let session: PeerTrustSession?

    var body: some View {
        let title = session?.stateLabel ?? "No active peer trust"
        let icon = session == nil ? "wave.3.right" : "checkmark.seal.fill"

        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)

            Text(summary)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(2)

            if let session {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 122 : 140, maximum: horizontalSizeClass == .compact ? 180 : 200), spacing: 10)], spacing: 10) {
                    trustFact(label: "Peer", value: session.peerName)
                    trustFact(label: "Transport", value: session.transportLabel)
                    trustFact(label: "Fingerprint", value: session.transcriptFingerprint)
                    trustFact(label: "Expires", value: session.expiresAt.formatted(date: .omitted, time: .shortened))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var summary: String {
        guard let session else {
            return "Vault reveal and high-consequence recovery should stay unavailable until an attested or nearby trust session is established."
        }
        return "\(session.peerName) is currently trusted via \(session.transportLabel). This session is short-lived and should be resealed after the privileged task completes."
    }

    private var tint: Color {
        guard let session else { return NumiPalette.coral }
        switch session.trustLevel {
        case .attestedLocal:
            return NumiPalette.gold
        case .nearbyVerified:
            return NumiPalette.mint
        }
    }

    private func trustFact(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.56))
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
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

private struct NumiTrustLedgerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let role: DeviceRole
    let signals: [NumiSignal]
    let peers: [TrustedPeerRecord]
    let events: [TrustLedgerEvent]
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = NumiDashboardLayoutMetrics(width: geometry.size.width)

            ZStack {
                NumiBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: metrics.isCompact ? 18 : 20) {
                        NumiGlassPanel(
                            eyebrow: role == .recoveryMac ? "Peer Console" : "Trust Ledger",
                            title: role == .recoveryMac ? "Mac keeps the local trust record" : "Peer history stays local and auditable",
                            subtitle: "Review durable peer state without crowding the main dashboard.",
                            icon: role == .recoveryMac ? "macwindow.on.rectangle" : "list.clipboard.fill",
                            accent: NumiPalette.coral
                        ) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 132 : 150, maximum: horizontalSizeClass == .compact ? 210 : 230), spacing: 12)], spacing: 12) {
                                ForEach(signals) { signal in
                                    NumiSignalTile(signal: signal)
                                }
                            }

                            if peers.isEmpty && events.isEmpty {
                                Text("No durable trust history exists yet. Establish a nearby session or stage recovery work to seed the ledger.")
                                    .font(.system(.footnote, design: .rounded).weight(.medium))
                                    .foregroundStyle(Color.white.opacity(0.72))
                            }
                        }

                        if !peers.isEmpty {
                            NumiGlassPanel(
                                eyebrow: "Known Peers",
                                title: "Trusted devices",
                                subtitle: "Current and historical peer bindings.",
                                icon: "person.2.fill",
                                accent: NumiPalette.aqua
                            ) {
                                ForEach(peers) { peer in
                                    NumiTrustedPeerCard(peer: peer)
                                }
                            }
                        }

                        if !events.isEmpty {
                            NumiGlassPanel(
                                eyebrow: "Recent Events",
                                title: "Ledger activity",
                                subtitle: "Session and recovery history.",
                                icon: "clock.badge.checkmark.fill",
                                accent: NumiPalette.gold
                            ) {
                                ForEach(events) { event in
                                    NumiTrustLedgerEventRow(event: event)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.topPadding + 58)
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
                    HStack {
                        Button(action: onDismiss) {
                            Label("Close Ledger", systemImage: "xmark")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        }
                                }
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: metrics.contentMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, metrics.isCompact ? 18 : 10)
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

private struct NumiTrustedPeerCard: View {
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 118 : 130, maximum: horizontalSizeClass == .compact ? 180 : 200), spacing: 10)], spacing: 10) {
                trustFact(label: "Fingerprint", value: peer.lastTranscriptFingerprint)
                trustFact(label: "Transport", value: transportLabel)
                trustFact(label: "Established", value: peer.lastEstablishedAt.formatted(date: .abbreviated, time: .shortened))
                trustFact(label: "Expires", value: peer.lastExpiresAt.formatted(date: .omitted, time: .shortened))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
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

    private func trustFact(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.56))
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
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

private struct NumiTrustLedgerEventRow: View {
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
        case .recoveryEnvelopePrepared:
            return NumiPalette.aqua
        case .recoveryEnvelopeConsumed:
            return NumiPalette.coral
        }
    }
}

private struct NumiEventRow: View {
    let event: WalletExperienceEvent
    let prominent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.systemImage)
                .font(.system(size: prominent ? 17 : 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 10) {
                    Text(event.title)
                        .font(.system(prominent ? .headline : .subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    Text(event.occurredAt, format: .dateTime.hour().minute())
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                Text(event.detail)
                    .font(.system(prominent ? .body : .footnote, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(prominent ? 0.84 : 0.66))
                    .lineSpacing(prominent ? 4 : 3)
                    .privacySensitive()
            }
        }
        .padding(prominent ? 16 : 0)
        .background {
            if prominent {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(tint.opacity(0.26), lineWidth: 1)
                    }
            }
        }
    }

    private var tint: Color {
        switch event.feedbackStyle {
        case .selection:
            return NumiPalette.aqua
        case .success:
            return NumiPalette.mint
        case .warning:
            return NumiPalette.gold
        case .error:
            return NumiPalette.coral
        }
    }
}

private enum NumiPrivilegedAuthenticationMode {
    case deviceOwner
    case biometric
}

private enum NumiPrivilegedAction: String, Identifiable {
    case unlockVault
    case sendDayPayment
    case sendVaultPayment
    case prepareRecoveryPair
    case recoverAuthority
    case importPeerShare
    case exportPeerShare
    case panicWipe

    var id: String { rawValue }

    var authenticationMode: NumiPrivilegedAuthenticationMode {
        switch self {
        case .sendDayPayment, .sendVaultPayment, .exportPeerShare:
            return .biometric
        case .unlockVault, .prepareRecoveryPair, .recoverAuthority, .importPeerShare, .panicWipe:
            return .deviceOwner
        }
    }

    var eyebrow: String {
        switch self {
        case .unlockVault:
            return "Vault Chamber Entry"
        case .sendDayPayment, .sendVaultPayment:
            return "Transfer Approval"
        case .prepareRecoveryPair:
            return "Recovery Pairing"
        case .recoverAuthority:
            return "Authority Re-enrollment"
        case .importPeerShare:
            return "Peer Share Import"
        case .exportPeerShare:
            return "Peer Share Export"
        case .panicWipe:
            return "Panic Custody Action"
        }
    }

    var title: String {
        switch self {
        case .unlockVault:
            return "Authorize vault chamber entry"
        case .sendDayPayment:
            return "Approve day-lane settlement"
        case .sendVaultPayment:
            return "Approve reserve-lane settlement"
        case .prepareRecoveryPair:
            return "Approve local recovery pair generation"
        case .recoverAuthority:
            return "Approve authority re-enrollment"
        case .importPeerShare:
            return "Approve peer share import"
        case .exportPeerShare:
            return "Approve peer share export"
        case .panicWipe:
            return "Approve local unwrap destruction"
        }
    }

    var subtitle: String {
        switch self {
        case .unlockVault:
            return "Vault visibility should feel deliberate and system-backed, not like a hidden disclosure row."
        case .sendDayPayment:
            return "The daily lane still requires explicit local approval before value leaves the device."
        case .sendVaultPayment:
            return "Reserve spending remains the highest-friction path in the product, by design."
        case .prepareRecoveryPair:
            return "Recovery material should only be staged after a visible, local owner confirmation."
        case .recoverAuthority:
            return "Replacing the authority root is a sovereign act and must stay explicit."
        case .importPeerShare:
            return "Importing custody material should be treated as a privileged trust transition."
        case .exportPeerShare:
            return "Exporting a peer fragment requires a tighter biometric gate before the sealed share leaves storage."
        case .panicWipe:
            return "Destroying local unwrap state is intentionally destructive and must never be ambient."
        }
    }

    var icon: String {
        switch self {
        case .unlockVault:
            return "lock.open.fill"
        case .sendDayPayment, .sendVaultPayment:
            return "paperplane.circle.fill"
        case .prepareRecoveryPair:
            return "person.2.fill"
        case .recoverAuthority:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .importPeerShare:
            return "square.and.arrow.down.fill"
        case .exportPeerShare:
            return "square.and.arrow.up.fill"
        case .panicWipe:
            return "flame.fill"
        }
    }

    var accent: Color {
        switch self {
        case .unlockVault:
            return NumiPalette.mint
        case .sendDayPayment, .sendVaultPayment:
            return NumiPalette.gold
        case .prepareRecoveryPair, .recoverAuthority, .importPeerShare, .exportPeerShare:
            return NumiPalette.aqua
        case .panicWipe:
            return NumiPalette.coral
        }
    }

    var localizedReason: String {
        switch self {
        case .unlockVault:
            return "Unlock Numi vault with local peer present"
        case .sendDayPayment, .sendVaultPayment:
            return "Approve Numi spend"
        case .prepareRecoveryPair:
            return "Prepare local-only recovery quorum"
        case .recoverAuthority:
            return "Re-enroll Numi authority from local recovery quorum"
        case .importPeerShare:
            return "Approve local recovery share import"
        case .exportPeerShare:
            return "Approve local recovery share export"
        case .panicWipe:
            return "Destroy local Numi vault unwrap state"
        }
    }

    var systemPromise: String {
        switch authenticationMode {
        case .deviceOwner:
            return "Numi will use Apple device-owner authentication and reuse that approval for the actual vault or recovery operation."
        case .biometric:
            return "Numi will use a biometric approval and reuse that authorization for the actual protected keychain read."
        }
    }
}

private struct NumiPrivilegedAuthenticationView: View {
    let action: NumiPrivilegedAction
    let onCancel: () -> Void
    let onAuthorize: (LAContext) -> Void

    @State private var isAuthorizing = false
    @State private var failureMessage: String?

    private let authClient = LocalAuthenticationClient()

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 760
            let contentMaxWidth: CGFloat = geometry.size.width >= 1100 ? 960 : .infinity
            let horizontalPadding: CGFloat = geometry.size.width < 430 ? 16 : (isCompact ? 18 : 22)
            let topPadding: CGFloat = geometry.size.width < 430 ? 18 : 22
            let bottomPadding: CGFloat = isCompact ? 148 : 160

            ZStack {
                NumiBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        NumiGlassPanel(
                            eyebrow: action.eyebrow,
                            title: action.title,
                            subtitle: action.subtitle,
                            icon: action.icon,
                            accent: action.accent
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(action.systemPromise)
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(Color.white.opacity(0.76))

                                ViewThatFits {
                                    HStack(spacing: 10) {
                                        NumiStateBadge(
                                            title: action.authenticationMode == .biometric ? "Biometric Gate" : "Owner Auth",
                                            icon: action.authenticationMode == .biometric ? "faceid" : "lock.iphone",
                                            tint: action.accent
                                        )
                                        NumiStateBadge(
                                            title: "Single Approval",
                                            icon: "checkmark.shield.fill",
                                            tint: NumiPalette.mint
                                        )
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        NumiStateBadge(
                                            title: action.authenticationMode == .biometric ? "Biometric Gate" : "Owner Auth",
                                            icon: action.authenticationMode == .biometric ? "faceid" : "lock.iphone",
                                            tint: action.accent
                                        )
                                        NumiStateBadge(
                                            title: "Single Approval",
                                            icon: "checkmark.shield.fill",
                                            tint: NumiPalette.mint
                                        )
                                    }
                                }
                            }
                        }

                        NumiGlassPanel(
                            eyebrow: "Trust Boundary",
                            title: "The system prompt comes next",
                            subtitle: "This surface exists so the user knows exactly why a local approval is about to happen.",
                            icon: "iphone.gen3.radiowaves.left.and.right",
                            accent: NumiPalette.gold
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Approval remains on-device. Numi does not send balances, recovery fragments, or signing secrets to a remote verifier to complete this step.")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(Color.white.opacity(0.72))

                                if let failureMessage {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Approval failed", systemImage: "exclamationmark.triangle.fill")
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(NumiPalette.coral)

                                        Text(failureMessage)
                                            .font(.system(.footnote, design: .rounded).weight(.medium))
                                            .foregroundStyle(Color.white.opacity(0.76))
                                    }
                                    .padding(14)
                                    .background {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(NumiPalette.coral.opacity(0.12))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                    .stroke(NumiPalette.coral.opacity(0.28), lineWidth: 1)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 12) {
                    Button(action: beginAuthorization) {
                        HStack(spacing: 12) {
                            if isAuthorizing {
                                ProgressView()
                                    .tint(NumiPalette.ink)
                            } else {
                                Image(systemName: action.icon)
                                    .font(.system(size: 16, weight: .bold))
                            }

                            Text(isAuthorizing ? "Awaiting System Approval" : primaryActionTitle)
                                .font(.system(.headline, design: .rounded).weight(.semibold))

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(NumiPalette.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(action.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthorizing)

                    Button(action: onCancel) {
                        Text("Return Without Approving")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthorizing)
                }
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, geometry.size.width < 430 ? 18 : 24)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var primaryActionTitle: String {
        let context = LAContext()
        var error: NSError?
        let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        switch action.authenticationMode {
        case .deviceOwner:
            if canUseBiometrics {
                switch context.biometryType {
                case .faceID:
                    return "Continue with Face ID or Passcode"
                case .touchID:
                    return "Continue with Touch ID or Passcode"
                default:
                    return "Continue with Device Owner Approval"
                }
            }
            return "Continue with Device Passcode"
        case .biometric:
            if canUseBiometrics {
                switch context.biometryType {
                case .faceID:
                    return "Continue with Face ID"
                case .touchID:
                    return "Continue with Touch ID"
                default:
                    return "Continue with Biometric Approval"
                }
            }
            return "Attempt Biometric Approval"
        }
    }

    private func beginAuthorization() {
        guard !isAuthorizing else { return }
        isAuthorizing = true
        failureMessage = nil

        Task {
            do {
                let context = try await authorize()
                await MainActor.run {
                    isAuthorizing = false
                    onAuthorize(context)
                }
            } catch {
                await MainActor.run {
                    isAuthorizing = false
                    if let walletError = error as? WalletError, case .userCancelled = walletError {
                        onCancel()
                    } else {
                        failureMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func authorize() async throws -> LAContext {
        switch action.authenticationMode {
        case .deviceOwner:
            return try await authClient.authenticateDeviceOwner(reason: action.localizedReason)
        case .biometric:
            return try await authClient.authenticateBiometric(reason: action.localizedReason)
        }
    }
}

#Preview {
    WalletDashboardView(model: WalletAppModel.preview())
}
