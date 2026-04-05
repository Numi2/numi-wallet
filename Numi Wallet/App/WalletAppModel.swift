import Combine
import Foundation
import LocalAuthentication
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class WalletAppModel: ObservableObject {
    @Published var dashboard: WalletDashboardState
    @Published var statusMessage = "Wallet core idle."
    @Published private(set) var latestEvent: WalletExperienceEvent?
    @Published private(set) var recentEvents: [WalletExperienceEvent] = []
    @Published var alias = "saffron-harbor"
    @Published var resolveAlias = "saffron-harbor"
    @Published var sendAmount = "12500"
    @Published var sendMaximumFee = "400"
    @Published var sendMemo = "Shielded settlement batch"
    @Published private(set) var peerTrustSession: PeerTrustSession?
    @Published private(set) var securityPosture: AppleSecurityPosture = .placeholder
    @Published private(set) var trustLedger: TrustLedgerSnapshot = .empty
    @Published var proofPolicy: ProofPolicy = .onDeviceOnly
    @Published var pairingCode = "Unavailable"
    @Published var pairingTransport = "Local pairing idle"
    @Published var pairingSessionFingerprint = "Session not attested"
    @Published var recoveryShareText = ""
    @Published var hasRecoveryShare = false
    @Published var resolvedDescriptorFingerprint = "No descriptor resolved"
    @Published var isScreenCaptureActive = false

    let role: DeviceRole

    private let localDeviceID: String
    private let configuration: RemoteServiceConfiguration
    private let rootVault: RootWalletVault
    private let recoveryPeerVault: RecoveryPeerVault
    private let pairingChannel: PairingChannel
    private let peerTrustCoordinator: PeerTrustCoordinator
    private let recoveryTransferCoordinator: RecoveryTransferCoordinator
    private let securityPostureClient: AppleSecurityPostureClient
    private let trustLedgerStore: TrustLedgerStore
    private var screenPrivacyMonitor: ScreenPrivacyMonitor?
    private var sensitiveDraftScrubTask: Task<Void, Never>?
    private var peerTrustExpiryTask: Task<Void, Never>?
    private var hasStarted = false

    init(configuration: RemoteServiceConfiguration, role: DeviceRole? = nil) {
        let role = role ?? Self.defaultRole()
        self.role = role
        self.dashboard = .placeholder(role: role)

        let keychain = KeychainStore()
        let keyManager = SecureEnclaveKeyManager(keychain: keychain)
        let descriptorSecretStore = DescriptorSecretStore(keychain: keychain)
        let ratchetSecretStore = RatchetSecretStore(keychain: keychain)
        let authClient = LocalAuthenticationClient()
        let appAttest = AppAttestProvider(keychain: keychain)
        let securityPostureClient = AppleSecurityPostureClient()
        let trustLedgerStore = TrustLedgerStore()
        let deviceID = Self.deviceID()
        self.localDeviceID = deviceID
        self.configuration = configuration
        let codec = EnvelopeCodec(configuration: configuration)
        let discovery = DiscoveryClient(configuration: configuration, codec: codec, appAttest: appAttest)
        let pirClient = PIRClient(configuration: configuration, codec: codec, appAttest: appAttest)
        let feeOracle = FeeOracleClient(configuration: configuration, codec: codec, appAttest: appAttest)
        let shieldedStateCoordinator = ShieldedStateCoordinator(
            configuration: configuration,
            pirClient: pirClient,
            descriptorSecretStore: descriptorSecretStore,
            ratchetSecretStore: ratchetSecretStore,
            tagRatchetEngine: TagRatchetEngine(),
            codec: codec
        )
        let relay = RelayClient(configuration: configuration, codec: codec, appAttest: appAttest)
        let pairingChannel = PairingChannel(keyManager: keyManager, appAttest: appAttest)

        self.pairingChannel = pairingChannel
        self.peerTrustCoordinator = PeerTrustCoordinator(pairingChannel: pairingChannel, localDeviceID: deviceID)
        self.recoveryTransferCoordinator = RecoveryTransferCoordinator(keyManager: keyManager, localDeviceID: deviceID)
        self.securityPostureClient = securityPostureClient
        self.trustLedgerStore = trustLedgerStore
        self.rootVault = RootWalletVault(
            role: role,
            deviceID: deviceID,
            stateStore: WalletStateStore(),
            keyManager: keyManager,
            descriptorSecretStore: descriptorSecretStore,
            ratchetSecretStore: ratchetSecretStore,
            authClient: authClient,
            policyEngine: PolicyEngine(),
            codec: codec,
            configuration: configuration,
            discoveryClient: discovery,
            shieldedStateCoordinator: shieldedStateCoordinator,
            dynamicFeeEngine: DynamicFeeEngine(configuration: configuration, feeOracle: feeOracle),
            relayClient: relay,
            prover: LocalProver()
        )
        self.recoveryPeerVault = RecoveryPeerVault(role: role, keychain: keychain, authClient: authClient)
        self.screenPrivacyMonitor = ScreenPrivacyMonitor { [weak self] event in
            self?.handleScreenPrivacyEvent(event)
        }
    }

    static func preview(role: DeviceRole = .authorityPhone) -> WalletAppModel {
        WalletAppModel(configuration: .preview, role: role)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        screenPrivacyMonitor?.start()
        Task {
            await loadTrustLedger()
            await refreshSecurityPosture()
            await preparePairingInvitation()
            await syncPeerTrustState(reason: nil)
            await refreshDashboard()
            if supportsPIRStateUpdates {
                await refreshShieldedState(trigger: .launch)
            }
            hasRecoveryShare = await recoveryPeerVault.hasShare()
            if recentEvents.isEmpty {
                recordEvent(.launchReady, detail: "Wallet core is ready on \(role.displayName). \(securityPosture.shortDescriptor.capitalized) with \(securityPosture.preferredTrustTransport) preferred for local trust.")
            }
        }
    }

    func refreshDashboard() async {
        do {
            dashboard = try await rootVault.dashboard(
                peerPresent: peerPresent,
                lastProofVenue: dashboard.proofVenue,
                privacyExposureDetected: privacyExposureDetected
            )
        } catch {
            recordFailure(error)
        }
    }

    private func refreshShieldedState(trigger: ShieldedRefreshTrigger) async {
        do {
            let report = try await rootVault.refreshShieldedState(trigger: trigger)
            await refreshDashboard()
            recordEvent(
                .shieldedStateRefreshed,
                detail: "PIR refresh complete. Height \(report.lastKnownBlockHeight), \(report.spendableNoteCount) spendable note(s), \(report.bandwidth.totalBytes) bytes."
            )
        } catch {
            await refreshDashboard()
            recordFailure(error)
        }
    }

    func initializeAuthorityWallet() {
        Task {
            do {
                _ = try await rootVault.initializeWallet(dayAlias: alias)
                await refreshDashboard()
                recordEvent(.authorityInitialized, detail: "Authority wallet initialized with hardware-backed root and split day/vault state.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func unlockDayWallet(authorizationContext: LAContext? = nil) {
        Task {
            do {
                if let authorizationContext {
                    _ = try await rootVault.unlockDayWallet(authorizationContext: authorizationContext)
                } else {
                    _ = try await rootVault.unlockDayWallet()
                }
                await refreshDashboard()
                recordEvent(.dayWalletUnlocked, detail: "Day wallet unlocked. Vault state remains hidden.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func unlockVault(authorizationContext: LAContext? = nil) {
        Task {
            do {
                if let authorizationContext {
                    _ = try await rootVault.unlockVault(
                        peerPresent: peerPresent,
                        privacyExposureDetected: privacyExposureDetected,
                        authorizationContext: authorizationContext
                    )
                } else {
                    _ = try await rootVault.unlockVault(
                        peerPresent: peerPresent,
                        privacyExposureDetected: privacyExposureDetected
                    )
                }
                await refreshDashboard()
                recordEvent(.vaultUnlocked, detail: "Vault unlocked with local authentication and peer presence.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func lockVault() {
        Task {
            await rootVault.lockVault()
            await refreshDashboard()
            recordEvent(.vaultSealed, detail: "Vault memory cleared from the local session.")
        }
    }

    func rotateDescriptor(for tier: WalletTier) {
        Task {
            do {
                let descriptor = try await rootVault.rotateDescriptor(
                    tier: tier,
                    peerPresent: peerPresent,
                    privacyExposureDetected: privacyExposureDetected
                )
                await refreshDashboard()
                recordEvent(.descriptorRotated, detail: "\(tier.displayName) descriptor rotated to \(descriptor.fingerprint).")
            } catch {
                recordFailure(error)
            }
        }
    }

    func registerAlias() {
        Task {
            do {
                try await rootVault.registerDayAlias(alias)
                await refreshDashboard()
                recordEvent(.aliasRegistered, detail: "Remote discovery updated with a blinded alias registration.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func resolveRemoteAlias() {
        Task {
            do {
                let descriptor = try await rootVault.resolveAlias(resolveAlias)
                if let descriptor {
                    resolvedDescriptorFingerprint = descriptor.fingerprint
                    recordEvent(.aliasResolved, detail: "Resolved a fresh offline receive descriptor without exposing a reusable address.")
                } else {
                    resolvedDescriptorFingerprint = "No descriptor resolved"
                    recordEvent(.aliasResolved, detail: "No descriptor is currently registered for that alias.")
                }
            } catch {
                recordFailure(error)
            }
        }
    }

    func sendDemoPayment(from tier: WalletTier, authorizationContext: LAContext? = nil) {
        Task {
            do {
                guard let amountMinorUnits = Int64(sendAmount) else {
                    recordFailure(detail: "Amount must be expressed in minor units.")
                    return
                }
                guard let maximumFeeMinorUnits = Int64(sendMaximumFee) else {
                    recordFailure(detail: "Maximum fee must be expressed in minor units.")
                    return
                }
                guard let descriptor = try await rootVault.resolveAlias(resolveAlias) else {
                    recordFailure(detail: "Resolve a descriptor before submitting a payment.")
                    return
                }
                let draft = SpendDraft(
                    id: UUID(),
                    tier: tier,
                    amount: MoneyAmount(minorUnits: amountMinorUnits, currencyCode: "NUMI"),
                    maximumFee: MoneyAmount(minorUnits: maximumFeeMinorUnits, currencyCode: "NUMI"),
                    memo: sendMemo,
                    destinationDescriptorID: descriptor.id,
                    confirmationTargetSeconds: 30,
                    createdAt: Date()
                )
                let receipt: RelaySubmissionReceipt
                if let authorizationContext {
                    receipt = try await rootVault.submitSpend(
                        draft,
                        peerPresent: peerPresent,
                        privacyExposureDetected: privacyExposureDetected,
                        descriptor: descriptor,
                        authorizationContext: authorizationContext
                    )
                } else {
                    receipt = try await rootVault.submitSpend(
                        draft,
                        peerPresent: peerPresent,
                        privacyExposureDetected: privacyExposureDetected,
                        descriptor: descriptor
                    )
                }
                await refreshDashboard()
                recordEvent(.transferSubmitted, detail: "Shielded spend submitted. Relay receipt: \(receipt.submissionID.uuidString.prefix(8)).")
            } catch {
                recordFailure(error)
            }
        }
    }

    func refreshShieldedState() {
        Task {
            guard supportsPIRStateUpdates else {
                await refreshDashboard()
                recordFailure(detail: "PIR state updates are inactive for the current coin profile.")
                return
            }
            await refreshShieldedState(trigger: .manual)
        }
    }

    func performBackgroundRefresh() async {
        guard supportsPIRStateUpdates else { return }
        await refreshShieldedState(trigger: .backgroundMaintenance)
    }

    func establishPeerTrust(with peerKind: PeerKind) {
        Task {
            do {
                let session = try await peerTrustCoordinator.establishSession(with: peerKind)
                peerTrustSession = session
                schedulePeerTrustExpiry(for: session)
                await persistTrustSessionEstablished(session)
                await refreshDashboard()
                recordEvent(
                    .peerPresenceEstablished,
                    detail: "Established \(session.stateLabel.lowercased()) trust with \(session.peerName). Session expires at \(session.expiresAt.formatted(date: .omitted, time: .shortened))."
                )
            } catch {
                recordFailure(error)
            }
        }
    }

    func clearPeerTrust() {
        Task {
            let priorSession = peerTrustSession
            await peerTrustCoordinator.clearSession()
            let priorPeerName = peerTrustSession?.peerName ?? "peer"
            peerTrustExpiryTask?.cancel()
            peerTrustExpiryTask = nil
            peerTrustSession = nil
            if let priorSession {
                await persistTrustSessionEnded(
                    priorSession,
                    didExpire: false,
                    reason: "\(priorSession.peerName) trust session was sealed and removed from the current wallet session."
                )
            }
            await refreshDashboard()
            recordEvent(.peerPresenceLost, detail: "\(priorPeerName) trust session was sealed and removed from the current wallet session.")
        }
    }

    func configureRecoveryPeers(authorizationContext: LAContext? = nil) {
        Task {
            do {
                let shares: [RecoveryShareEnvelope]
                if let authorizationContext {
                    shares = try await rootVault.configureRecoveryQuorum(authorizationContext: authorizationContext)
                } else {
                    shares = try await rootVault.configureRecoveryQuorum()
                }
                let envelope = try await recoveryTransferCoordinator.makeEnvelope(
                    payload: .authorityBundle(shares),
                    senderRole: role,
                    recipientRole: .authorityPhone,
                    trustSession: peerTrustSession
                )
                stageRecoveryWorkspace(with: try encodeRecoveryTransferEnvelope(envelope))
                await persistTransferEnvelope(envelope, action: .prepared)
                await refreshDashboard()
                recordEvent(.recoveryPrepared, detail: "Local-only recovery quorum prepared. Both peer fragments are required for new-device enrollment.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func importRecoveryShare(authorizationContext: LAContext? = nil) {
        Task {
            do {
                let sourceEnvelope = decodeRecoveryTransferEnvelope(from: recoveryShareText)
                let payload = try await recoveryTransferCoordinator.resolvePayload(from: recoveryShareText, recipientRole: role)
                guard case .peerShare(let share) = payload else {
                    throw WalletError.invalidRecoveryTransfer
                }
                if let authorizationContext {
                    try await recoveryPeerVault.storeShare(share, authorizationContext: authorizationContext)
                } else {
                    try await recoveryPeerVault.storeShare(share)
                }
                hasRecoveryShare = await recoveryPeerVault.hasShare()
                clearRecoveryWorkspace()
                if let sourceEnvelope {
                    await persistTransferEnvelope(sourceEnvelope, action: .consumed)
                }
                recordEvent(.recoveryShareImported, detail: "Recovery share imported into device-only, biometry-gated storage.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func exportRecoveryShare(authorizationContext: LAContext? = nil) {
        Task {
            do {
                let share: RecoveryShareEnvelope
                if let authorizationContext {
                    share = try await recoveryPeerVault.exportShare(authorizationContext: authorizationContext)
                } else {
                    share = try await recoveryPeerVault.exportShare()
                }
                let envelope = try await recoveryTransferCoordinator.makeEnvelope(
                    payload: .peerShare(share),
                    senderRole: role,
                    recipientRole: .authorityPhone,
                    trustSession: peerTrustSession
                )
                stageRecoveryWorkspace(with: try encodeRecoveryTransferEnvelope(envelope))
                await persistTransferEnvelope(envelope, action: .prepared)
                recordEvent(.recoveryShareExported, detail: "Recovery share export approved locally.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func recoverAuthorityFromBundle(authorizationContext: LAContext? = nil) {
        Task {
            do {
                let sourceEnvelope = decodeRecoveryTransferEnvelope(from: recoveryShareText)
                let payload = try await recoveryTransferCoordinator.resolvePayload(from: recoveryShareText, recipientRole: .authorityPhone)
                guard case .authorityBundle(let shares) = payload else {
                    throw WalletError.invalidRecoveryTransfer
                }
                if let authorizationContext {
                    _ = try await rootVault.recoverAuthority(from: shares, authorizationContext: authorizationContext)
                } else {
                    _ = try await rootVault.recoverAuthority(from: shares)
                }
                clearRecoveryWorkspace()
                if let sourceEnvelope {
                    await persistTransferEnvelope(sourceEnvelope, action: .consumed)
                }
                await refreshDashboard()
                recordEvent(.authorityRecovered, detail: "Authority iPhone re-enrolled from local quorum. A new hardware root is now active.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func panicWipe(authorizationContext: LAContext? = nil) {
        Task {
            do {
                if let authorizationContext {
                    try await rootVault.panicDestroyLocalUnwrapState(authorizationContext: authorizationContext)
                } else {
                    try await rootVault.panicDestroyLocalUnwrapState()
                }
                await refreshDashboard()
                recordEvent(.panicWipe, detail: "Local vault unwrap state destroyed. Recovery now requires the peer quorum.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func runProof() {
        Task {
            do {
                let artifact = try await rootVault.runProof(policy: proofPolicy)
                dashboard.proofVenue = artifact.venue
                await refreshDashboard()
                recordEvent(
                    .proofCompleted,
                    detail: "Local proof flow completed in \(artifact.duration.formatted(.number.precision(.fractionLength(3))))s via \(artifact.venue)."
                )
            } catch {
                recordFailure(error)
            }
        }
    }

    private func preparePairingInvitation() async {
        do {
            let invitation = try await pairingChannel.makeInvitation()
            let transcript = try await pairingChannel.makeSessionTranscript(
                for: invitation,
                peerDeviceID: Self.deviceID(),
                peerRole: role
            )
            pairingCode = invitation.bootstrapCode
            pairingTransport = invitation.transport == .nearbyInteraction ? "Nearby Interaction + Network.framework" : "Network.framework"
            pairingSessionFingerprint = transcript.fingerprint
        } catch {
            pairingTransport = error.localizedDescription
            recordFailure(error)
        }
    }

    private static func deviceID() -> String {
        let key = "numi.device-id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    private static func defaultRole() -> DeviceRole {
        #if os(macOS)
        return .recoveryMac
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone ? .authorityPhone : .recoveryPad
        #else
        return .authorityPhone
        #endif
    }

    func handleScenePhase(_ phase: ScenePhase) {
        Task {
            if phase != .active {
                await handleProtectedTransition(reason: "App moved out of the foreground. Sensitive state was redacted.")
            } else {
                await refreshSecurityPosture()
                await syncPeerTrustState(reason: nil)
                if supportsPIRStateUpdates {
                    await refreshShieldedState(trigger: .foregroundResume)
                } else {
                    await refreshDashboard()
                }
            }
        }
    }

    var supportsAliasDiscovery: Bool {
        configuration.supportsAliasDiscovery
    }

    var supportsPIRStateUpdates: Bool {
        configuration.supportsPIRStateUpdates
    }

    var supportsShieldedSend: Bool {
        configuration.supportsShieldedSpendPipeline
    }

    var usesDynamicFeeMarkets: Bool {
        configuration.supportsDynamicFeeMarkets
    }

    var supportsBackgroundRefresh: Bool {
        configuration.supportsBackgroundPIRRefresh
    }

    var peerPresent: Bool {
        peerTrustSession?.isActive == true
    }

    var peerTrustStatus: String {
        guard let peerTrustSession else { return "No active trust session" }
        return "\(peerTrustSession.peerName) • \(peerTrustSession.stateLabel)"
    }

    var recoveryWorkspaceSummary: RecoveryWorkspaceSummary {
        RecoveryWorkspaceInspector.inspect(text: recoveryShareText)
    }

    var shouldRedactUI: Bool {
        dashboard.isPrivacyRedacted || isScreenCaptureActive
    }

    private var privacyExposureDetected: Bool {
        isScreenCaptureActive
    }

    private func handleScreenPrivacyEvent(_ event: ScreenPrivacyMonitor.Event) {
        isScreenCaptureActive = event.isCaptured
        Task {
            if event.protectedDataWillBecomeUnavailable {
                await handleProtectedTransition(reason: "Protected data is becoming unavailable. Sensitive state was cleared.")
            } else if event.screenshotDetected {
                await handleProtectedTransition(reason: "Screenshot detected. Vault session cleared and sensitive UI redacted.")
            } else if event.isCaptured {
                await handleProtectedTransition(reason: "Active screen capture detected. Vault session cleared and sensitive UI redacted.")
            } else {
                await refreshDashboard()
            }
        }
    }

    private func handleProtectedTransition(reason: String) async {
        let priorSession = peerTrustSession
        await rootVault.suspendSensitiveMemory()
        await peerTrustCoordinator.clearSession()
        peerTrustExpiryTask?.cancel()
        peerTrustExpiryTask = nil
        peerTrustSession = nil
        clearRecoveryWorkspace()
        dashboard = WalletDashboardState(
            role: role,
            isInitialized: dashboard.isInitialized,
            isVaultUnlocked: false,
            isPeerPresent: peerPresent,
            dayBalance: "Redacted",
            vaultBalance: nil,
            dayDescriptorFingerprint: "Redacted",
            vaultDescriptorFingerprint: nil,
            proofVenue: dashboard.proofVenue,
            isPrivacyRedacted: true,
            captureDetected: isScreenCaptureActive,
            pirStatus: dashboard.pirStatus,
            lastPIRRefresh: dashboard.lastPIRRefresh,
            payReadiness: "Redacted",
            lastFeeQuote: dashboard.lastFeeQuote,
            trackedTagRelationships: dashboard.trackedTagRelationships,
            trackedNotes: dashboard.trackedNotes
        )
        if let priorSession {
            await persistTrustSessionEnded(priorSession, didExpire: false, reason: reason)
        }
        await refreshSecurityPosture()
        recordEvent(.privacyShieldRaised, detail: reason)
    }

    private func stageRecoveryWorkspace(with data: Data) {
        var mutableData = data
        defer { mutableData.zeroize() }
        recoveryShareText = String(decoding: mutableData, as: UTF8.self)
        scheduleSensitiveDraftScrub()
    }

    private func clearRecoveryWorkspace() {
        sensitiveDraftScrubTask?.cancel()
        sensitiveDraftScrubTask = nil
        recoveryShareText = ""
    }

    private func encodeRecoveryTransferEnvelope(_ envelope: RecoveryTransferEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    private func scheduleSensitiveDraftScrub(after seconds: TimeInterval = 120) {
        sensitiveDraftScrubTask?.cancel()
        guard !recoveryShareText.isEmpty else { return }
        sensitiveDraftScrubTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.clearRecoveryWorkspace()
                if let self,
                   self.latestEvent?.kind == .recoveryShareExported || self.latestEvent?.kind == .recoveryPrepared {
                    self.recordEvent(.sensitiveWorkspaceScrubbed, detail: "Sensitive recovery workspace scrubbed from memory.")
                }
            }
        }
    }

    private func syncPeerTrustState(reason: String?) async {
        let previousSession = peerTrustSession
        let currentSession = await peerTrustCoordinator.currentSession()
        peerTrustSession = currentSession

        guard previousSession?.id != currentSession?.id else { return }
        if previousSession != nil, currentSession == nil {
            peerTrustExpiryTask?.cancel()
            peerTrustExpiryTask = nil
            if let previousSession {
                await persistTrustSessionEnded(
                    previousSession,
                    didExpire: true,
                    reason: reason ?? "The active peer trust session expired or was removed. Vault policy returns to a sealed posture."
                )
            }
            recordEvent(
                .peerPresenceLost,
                detail: reason ?? "The active peer trust session expired or was removed. Vault policy returns to a sealed posture."
            )
        }
    }

    private func refreshSecurityPosture() async {
        securityPosture = securityPostureClient.scan(role: role, isScreenCaptureActive: isScreenCaptureActive)
    }

    private func loadTrustLedger() async {
        do {
            trustLedger = try await trustLedgerStore.load(deviceID: localDeviceID, role: role)
        } catch {
            trustLedger = .empty
        }
    }

    private func schedulePeerTrustExpiry(for session: PeerTrustSession) {
        peerTrustExpiryTask?.cancel()
        let interval = max(0, session.expiresAt.timeIntervalSinceNow)
        peerTrustExpiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncPeerTrustState(reason: "The active peer trust session expired. Re-establish nearby trust before opening the vault again.")
        }
    }

    private func persistTrustSessionEstablished(_ session: PeerTrustSession) async {
        do {
            trustLedger = try await trustLedgerStore.recordSessionEstablished(
                session,
                deviceID: localDeviceID,
                localRole: role
            )
        } catch {
            recordFailure(detail: "Trust ledger could not record the active peer session.")
        }
    }

    private func persistTrustSessionEnded(_ session: PeerTrustSession, didExpire: Bool, reason: String) async {
        do {
            trustLedger = try await trustLedgerStore.recordSessionEnded(
                session,
                deviceID: localDeviceID,
                localRole: role,
                didExpire: didExpire,
                reason: reason
            )
        } catch {
            recordFailure(detail: "Trust ledger could not record the sealed peer session.")
        }
    }

    private func persistTransferEnvelope(_ envelope: RecoveryTransferEnvelope, action: TrustLedgerTransferAction) async {
        do {
            trustLedger = try await trustLedgerStore.recordTransferEnvelope(
                envelope,
                action: action,
                deviceID: localDeviceID,
                localRole: role
            )
        } catch {
            recordFailure(detail: "Trust ledger could not record the recovery transfer envelope.")
        }
    }

    private func decodeRecoveryTransferEnvelope(from text: String) -> RecoveryTransferEnvelope? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? JSONDecoder().decode(RecoveryTransferEnvelope.self, from: Data(trimmed.utf8))
    }

    private func recordEvent(_ kind: WalletExperienceEventKind, detail: String) {
        let event = WalletExperienceEvent(kind: kind, detail: detail)
        latestEvent = event
        statusMessage = detail
        recentEvents = [event] + Array(recentEvents.prefix(5))
    }

    private func recordFailure(_ error: Error) {
        recordFailure(detail: error.localizedDescription)
    }

    private func recordFailure(detail: String) {
        recordEvent(.failure, detail: detail)
    }
}
