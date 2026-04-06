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
    @Published var pairingSessionFingerprint = "Awaiting authenticated local session"
    @Published private(set) var visibleLocalPeerCount = 0
    @Published private(set) var visibleLocalPeerRoles: [DeviceRole] = []
    @Published private(set) var pendingIncomingRecoveryTransferCount = 0
    @Published private(set) var pendingIncomingRecoveryTransferPreview: PendingRecoveryTransferPreview?
    @Published var hasRecoveryShare = false
    @Published var resolvedDescriptorFingerprint = "No descriptor resolved"
    @Published var isScreenCaptureActive = false
    @Published private(set) var stagedRecoveryTransfer: StagedRecoveryTransfer?

    let role: DeviceRole

    private let localDeviceID: String
    private let configuration: RemoteServiceConfiguration
    private let rootVault: RootWalletVault
    private let recoveryPeerVault: RecoveryPeerVault
    private let localPeerTransport: AuthenticatedLocalPeerTransport
    private let peerTrustCoordinator: PeerTrustCoordinator
    private let recoveryTransferCoordinator: RecoveryTransferCoordinator
    private let recoveryTransferQRCodeScanner: RecoveryTransferQRCodeScanner
    private let securityPostureClient: AppleSecurityPostureClient
    private let trustLedgerStore: TrustLedgerStore
    private var screenPrivacyMonitor: ScreenPrivacyMonitor?
    private var sensitiveDraftScrubTask: Task<Void, Never>?
    private var peerTrustExpiryTask: Task<Void, Never>?
    private var localPeerTransportObservationTask: Task<Void, Never>?
    private var pendingPeerTrustLossReason: String?
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
        let localPeerTransport = AuthenticatedLocalPeerTransport(pairingChannel: pairingChannel)

        self.localPeerTransport = localPeerTransport
        self.peerTrustCoordinator = PeerTrustCoordinator(pairingChannel: pairingChannel)
        self.recoveryTransferCoordinator = RecoveryTransferCoordinator(keyManager: keyManager, localDeviceID: deviceID)
        self.recoveryTransferQRCodeScanner = RecoveryTransferQRCodeScanner()
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
        startObservingLocalPeerTransport()
        Task {
            await rootVault.prepareTachyonProofContinuation()
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
                detail: "PIR refresh \(report.readinessClassification.displayName.lowercased()). Height \(report.lastKnownBlockHeight), discovered \(report.discoveredNoteCount), verified \(report.verifiedNoteCount), witness-fresh \(report.witnessFreshNoteCount), spendable \(report.spendableNoteCount), deferred \(report.deferredMatchCount), mismatches \(report.mismatchCount), \(report.bandwidth.totalBytes) bytes."
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
                let peerPresenceContext = try await requiredPeerPresenceContext()
                if let authorizationContext {
                    _ = try await rootVault.unlockVault(
                        peerTrustSession: peerPresenceContext.session,
                        peerPresenceAssertion: peerPresenceContext.assertion,
                        privacyExposureDetected: privacyExposureDetected,
                        authorizationContext: authorizationContext
                    )
                } else {
                    _ = try await rootVault.unlockVault(
                        peerTrustSession: peerPresenceContext.session,
                        peerPresenceAssertion: peerPresenceContext.assertion,
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
                let peerPresenceContext = try await peerPresenceContext(required: tier == .vault)
                let descriptor = try await rootVault.rotateDescriptor(
                    tier: tier,
                    peerTrustSession: peerPresenceContext.session,
                    peerPresenceAssertion: peerPresenceContext.assertion,
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
                let peerPresenceContext = try await peerPresenceContext(required: false)
                let receipt: RelaySubmissionReceipt
                if let authorizationContext {
                    receipt = try await rootVault.submitSpend(
                        draft,
                        peerTrustSession: peerPresenceContext.session,
                        peerPresenceAssertion: peerPresenceContext.assertion,
                        privacyExposureDetected: privacyExposureDetected,
                        descriptor: descriptor,
                        authorizationContext: authorizationContext
                    )
                } else {
                    receipt = try await rootVault.submitSpend(
                        draft,
                        peerTrustSession: peerPresenceContext.session,
                        peerPresenceAssertion: peerPresenceContext.assertion,
                        privacyExposureDetected: privacyExposureDetected,
                        descriptor: descriptor
                    )
                }
                await refreshDashboard()
                recordEvent(.transferSubmitted, detail: "Shielded spend submitted. Relay receipt: \(receipt.submissionID.uuidString.prefix(8)).")
            } catch {
                if let walletError = error as? WalletError,
                   case .resumableProofPending = walletError {
                    await refreshDashboard()
                    recordEvent(.proofDeferred, detail: walletError.localizedDescription)
                    return
                }
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
                _ = try await localPeerTransport.establishSession(preferredPeerKind: peerKind)
                await handleLocalPeerTransportSnapshot(await localPeerTransport.currentSnapshot())
            } catch {
                await refreshLocalPeerTransportState()
                recordFailure(error)
            }
        }
    }

    func clearPeerTrust() {
        Task {
            let priorSession = peerTrustSession
            if let priorSession {
                pendingPeerTrustLossReason = "The active peer trust session was deliberately sealed. Vault policy returns to a sealed posture."
                await localPeerTransport.sealSession(priorSession.id)
            } else {
                await peerTrustCoordinator.clearSession()
            }
            await refreshLocalPeerTransportState()
            await refreshDashboard()
        }
    }

    func revokePeerTrustRecord(_ peerDeviceID: String) {
        Task {
            guard let peer = trustLedger.peers.first(where: { $0.peerDeviceID == peerDeviceID }) else {
                return
            }

            let reason = "Local trust with \(peer.peerName) was revoked on \(role.displayName). This peer must not regain privileged trust until it is deliberately re-enrolled."
            do {
                trustLedger = try await trustLedgerStore.revokePeer(
                    deviceID: peerDeviceID,
                    reason: reason,
                    deviceID: localDeviceID,
                    localRole: role
                )

                if peerTrustSession?.peerDeviceID == peerDeviceID,
                   let activeSessionID = peerTrustSession?.id {
                    pendingPeerTrustLossReason = reason
                    await localPeerTransport.sealSession(activeSessionID)
                } else {
                    await refreshDashboard()
                    recordEvent(.peerPresenceLost, detail: reason)
                }
            } catch {
                recordFailure(detail: "Trust ledger could not revoke the selected peer.")
            }
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
                stageRecoveryTransfer(envelope: envelope)
                await persistTransferEnvelope(envelope, action: .prepared)
                await refreshDashboard()
                recordEvent(.recoveryPrepared, detail: "Local-only recovery quorum prepared. Move the signed recovery document to the new authority device through the system share sheet or bounded QR lane when re-enrollment is required.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func importRecoveryShare(authorizationContext: LAContext? = nil) {
        Task {
            do {
                let peerPresenceContext = try await requiredPeerPresenceContext()
                guard let stagedRecoveryTransfer else {
                    throw WalletError.invalidRecoveryTransferDocument
                }
                let sourceEnvelope = stagedRecoveryTransfer.document.envelope
                let payload = try await recoveryTransferCoordinator.resolvePayload(
                    from: stagedRecoveryTransfer.document,
                    recipientRole: role,
                    activeTrustSession: peerPresenceContext.session,
                    peerPresenceAssertion: peerPresenceContext.assertion
                )
                guard case .peerShare(let share) = payload else {
                    throw WalletError.invalidRecoveryTransfer
                }
                if let authorizationContext {
                    try await recoveryPeerVault.storeShare(share, authorizationContext: authorizationContext)
                } else {
                    try await recoveryPeerVault.storeShare(share)
                }
                hasRecoveryShare = await recoveryPeerVault.hasShare()
                clearStagedRecoveryTransfer()
                await persistTransferEnvelope(sourceEnvelope, action: .consumed)
                recordEvent(.recoveryShareImported, detail: "Recovery share imported into device-only, biometry-gated storage.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func exportRecoveryShare(authorizationContext: LAContext? = nil) {
        Task {
            do {
                let peerPresenceContext = try await requiredPeerPresenceContext()
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
                    trustSession: peerPresenceContext.session,
                    peerPresenceAssertion: peerPresenceContext.assertion
                )
                stageRecoveryTransfer(envelope: envelope)
                await persistTransferEnvelope(envelope, action: .prepared)
                recordEvent(.recoveryShareExported, detail: "Recovery share export approved locally. Move the signed transfer document to the authority iPhone through the system share sheet or bounded QR lane.")
            } catch {
                recordFailure(error)
            }
        }
    }

    func transmitStagedRecoveryTransfer(authorizationContext _: LAContext? = nil) {
        Task {
            do {
                guard let stagedRecoveryTransfer else {
                    throw WalletError.invalidRecoveryTransferDocument
                }
                let receipt = try await localPeerTransport.sendRecoveryTransfer(stagedRecoveryTransfer.document)
                clearStagedRecoveryTransfer()
                await refreshLocalPeerTransportState()
                recordEvent(
                    .recoveryTransferDispatched,
                    detail: "Signed recovery transfer delivered to \(receipt.remotePeerName) over authenticated local session \(receipt.sessionID.uuidString.prefix(8))."
                )
            } catch {
                recordFailure(error)
            }
        }
    }

    func approvePendingIncomingRecoveryTransfer(authorizationContext _: LAContext? = nil) {
        Task {
            do {
                guard stagedRecoveryTransfer == nil else {
                    recordFailure(detail: "Clear the currently staged recovery transfer before approving a new authenticated local delivery.")
                    return
                }
                guard let preview = pendingIncomingRecoveryTransferPreview else {
                    throw WalletError.invalidRecoveryTransferDocument
                }
                guard let transfer = await localPeerTransport.consumePendingRecoveryTransfer(id: preview.id) else {
                    throw WalletError.invalidRecoveryTransferDocument
                }
                try stageRecoveryTransfer(document: transfer.document)
                await refreshLocalPeerTransportState()
                await syncPendingIncomingRecoveryTransferPreview()
                recordEvent(
                    .recoveryTransferLoaded,
                    detail: "Authenticated local recovery transfer from \(transfer.peerName) approved and staged. Review the signed transfer lane before approving any custody action."
                )
            } catch {
                recordFailure(error)
            }
        }
    }

    func rejectPendingIncomingRecoveryTransfer() {
        Task {
            guard let preview = pendingIncomingRecoveryTransferPreview else { return }
            await localPeerTransport.discardPendingRecoveryTransfer(id: preview.id)
            pendingIncomingRecoveryTransferPreview = nil
            await refreshLocalPeerTransportState()
            await syncPendingIncomingRecoveryTransferPreview()
            recordEvent(
                .recoveryTransferRejected,
                detail: "Rejected authenticated local recovery transfer from \(preview.sourceLabel). The pending inbox item was discarded without staging custody material."
            )
        }
    }

    func recoverAuthorityFromBundle(authorizationContext: LAContext? = nil) {
        Task {
            do {
                guard let stagedRecoveryTransfer else {
                    throw WalletError.invalidRecoveryTransferDocument
                }
                let sourceEnvelope = stagedRecoveryTransfer.document.envelope
                let payload = try await recoveryTransferCoordinator.resolvePayload(
                    from: stagedRecoveryTransfer.document,
                    recipientRole: .authorityPhone
                )
                guard case .authorityBundle(let shares) = payload else {
                    throw WalletError.invalidRecoveryTransfer
                }
                if let authorizationContext {
                    _ = try await rootVault.recoverAuthority(from: shares, authorizationContext: authorizationContext)
                } else {
                    _ = try await rootVault.recoverAuthority(from: shares)
                }
                clearStagedRecoveryTransfer()
                await persistTransferEnvelope(sourceEnvelope, action: .consumed)
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

    func resumePendingShieldedSend(checkpointID: UUID, authorizationContext: LAContext) {
        Task {
            do {
                let sendLabel = dashboard.pendingShieldedSends.first(where: { $0.id == checkpointID })
                    .map { "\($0.amount) • \($0.counterpartyLabel)" }
                    ?? "pending shielded spend"
                let peerPresenceContext = try await peerPresenceContext(required: false)
                let receipt = try await rootVault.resumePendingShieldedSend(
                    checkpointID: checkpointID,
                    peerTrustSession: peerPresenceContext.session,
                    peerPresenceAssertion: peerPresenceContext.assertion,
                    privacyExposureDetected: privacyExposureDetected,
                    authorizationContext: authorizationContext
                )
                await refreshDashboard()
                recordEvent(.transferSubmitted, detail: "Resumed \(sendLabel). Relay receipt: \(receipt.submissionID.uuidString.prefix(8)).")
            } catch {
                if let walletError = error as? WalletError,
                   case .resumableProofPending = walletError {
                    await refreshDashboard()
                    recordEvent(.proofDeferred, detail: walletError.localizedDescription)
                    return
                }
                recordFailure(error)
            }
        }
    }

    func discardPendingShieldedSend(checkpointID: UUID, authorizationContext _: LAContext) {
        Task {
            do {
                let sendLabel = dashboard.pendingShieldedSends.first(where: { $0.id == checkpointID })
                    .map { "\($0.amount) • \($0.counterpartyLabel)" }
                    ?? "pending shielded spend"
                try await rootVault.discardPendingShieldedSend(checkpointID: checkpointID)
                await refreshDashboard()
                recordEvent(.proofDiscarded, detail: "Discarded \(sendLabel) from the persisted proof queue.")
            } catch {
                if let walletError = error as? WalletError,
                   case .resumableProofPending = walletError {
                    await refreshDashboard()
                    recordEvent(.proofDeferred, detail: walletError.localizedDescription)
                    return
                }
                recordFailure(error)
            }
        }
    }

    private func preparePairingInvitation() async {
        do {
            let snapshot = try await localPeerTransport.activate(
                localDeviceID: localDeviceID,
                localRole: role,
                peerName: localPeerName()
            )
            applyLocalPeerTransportSnapshot(snapshot)
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
                await refreshLocalPeerTransportState()
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

    var hasStagedRecoveryTransfer: Bool {
        stagedRecoveryTransfer != nil
    }

    var canDispatchStagedRecoveryTransfer: Bool {
        guard let stagedRecoveryTransfer else {
            return false
        }
        return visibleLocalPeerRoles.contains(stagedRecoveryTransfer.document.envelope.recipientRole)
    }

    var canApprovePendingIncomingRecoveryTransfer: Bool {
        pendingIncomingRecoveryTransferPreview != nil && stagedRecoveryTransfer == nil
    }

    var stagedRecoveryTransferFileURL: URL? {
        stagedRecoveryTransfer?.fileURL
    }

    var stagedRecoveryTransferQRCodeChunks: [RecoveryTransferQRCodeChunk] {
        stagedRecoveryTransfer?.qrChunks ?? []
    }

    var recoveryWorkspaceSummary: RecoveryWorkspaceSummary {
        RecoveryWorkspaceInspector.inspect(stagedTransfer: stagedRecoveryTransfer)
    }

    var shouldRedactUI: Bool {
        dashboard.isPrivacyRedacted || isScreenCaptureActive
    }

    private var privacyExposureDetected: Bool {
        isScreenCaptureActive
    }

    private func requiredPeerPresenceContext() async throws -> (session: PeerTrustSession, assertion: PeerPresenceAssertion) {
        guard let session = peerTrustSession, session.isActive else {
            throw WalletError.peerPresenceRequired
        }
        let assertion = try await peerTrustCoordinator.issuePresenceAssertion()
        return (session, assertion)
    }

    private func peerPresenceContext(required: Bool) async throws -> (session: PeerTrustSession?, assertion: PeerPresenceAssertion?) {
        if required {
            let context = try await requiredPeerPresenceContext()
            return (context.session, context.assertion)
        }
        guard let session = peerTrustSession, session.isActive else {
            return (nil, nil)
        }
        let assertion = try await peerTrustCoordinator.issuePresenceAssertion()
        return (session, assertion)
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
        clearStagedRecoveryTransfer()
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
            proofQueueStatus: dashboard.proofQueueStatus,
            pendingShieldedSends: [],
            isPrivacyRedacted: true,
            captureDetected: isScreenCaptureActive,
            pirStatus: dashboard.pirStatus,
            lastPIRRefresh: dashboard.lastPIRRefresh,
            payReadiness: "Redacted",
            relationshipPosture: dashboard.relationshipPosture,
            receiveSummary: dashboard.receiveSummary,
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

    func loadRecoveryTransferDocument(data: Data, suggestedFileName: String) {
        do {
            let document = try RecoveryTransferDocument.decode(from: data)
            try stageRecoveryTransfer(document: document)
            recordEvent(.recoveryTransferLoaded, detail: "Recovery transfer loaded from \(suggestedFileName). Review the signed transfer lane before approving any custody action.")
        } catch {
            recordFailure(error)
        }
    }

    func loadRecoveryTransferQRCodeImages(_ assets: [RecoveryTransferImportAsset]) {
        do {
            let document = try recoveryTransferQRCodeScanner.assembleDocument(from: assets)
            try stageRecoveryTransfer(document: document)
            recordEvent(.recoveryTransferLoaded, detail: "Recovery transfer assembled from \(assets.count) QR chunk image(s). Review the signed transfer lane before approving any custody action.")
        } catch {
            recordFailure(error)
        }
    }

    func clearStagedRecoveryTransfer() {
        sensitiveDraftScrubTask?.cancel()
        sensitiveDraftScrubTask = nil
        if let stagedRecoveryTransferFileURL = stagedRecoveryTransfer?.fileURL {
            try? FileManager.default.removeItem(at: stagedRecoveryTransferFileURL)
        }
        stagedRecoveryTransfer = nil
        Task {
            await syncPendingIncomingRecoveryTransferPreview()
        }
    }

    private func stageRecoveryTransfer(envelope: RecoveryTransferEnvelope) {
        do {
            try stageRecoveryTransfer(document: RecoveryTransferDocument.make(from: envelope))
        } catch {
            recordFailure(error)
        }
    }

    private func stageRecoveryTransfer(document: RecoveryTransferDocument) throws {
        let fileURL = writeTransferFileIfPossible(for: document)
        let qrChunks = try RecoveryTransferQRCodeCodec.makeChunks(for: document)
        stagedRecoveryTransfer = StagedRecoveryTransfer(
            document: document,
            fileURL: fileURL,
            qrChunks: qrChunks
        )
        scheduleSensitiveDraftScrub()
    }

    private func scheduleSensitiveDraftScrub(after seconds: TimeInterval = 120) {
        sensitiveDraftScrubTask?.cancel()
        guard hasStagedRecoveryTransfer else { return }
        sensitiveDraftScrubTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.clearStagedRecoveryTransfer()
                if let self,
                   self.latestEvent?.kind == .recoveryShareExported || self.latestEvent?.kind == .recoveryPrepared {
                    self.recordEvent(.sensitiveWorkspaceScrubbed, detail: "Sensitive recovery transfer scrubbed from memory.")
                }
            }
        }
    }

    private func syncPeerTrustState(reason: String?) async {
        await syncPeerTrustFromTransport(reason: reason)
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

    private func writeTransferFileIfPossible(for document: RecoveryTransferDocument) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            document.recommendedFilename,
            isDirectory: false
        )
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            let data = try RecoveryTransferDocument.encode(document)
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
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

    private func startObservingLocalPeerTransport() {
        localPeerTransportObservationTask?.cancel()
        localPeerTransportObservationTask = Task { [weak self] in
            guard let self else { return }
            let updates = await self.localPeerTransport.updates()
            for await snapshot in updates {
                await self.handleLocalPeerTransportSnapshot(snapshot)
            }
        }
    }

    private func handleLocalPeerTransportSnapshot(_ snapshot: LocalPeerTransportSnapshot) async {
        applyLocalPeerTransportSnapshot(snapshot)
        await syncPendingIncomingRecoveryTransferPreview()
        await syncPeerTrustFromTransport(reason: nil)
    }

    private func refreshLocalPeerTransportState() async {
        let snapshot = await localPeerTransport.currentSnapshot()
        applyLocalPeerTransportSnapshot(snapshot)
        await syncPendingIncomingRecoveryTransferPreview()
    }

    private func applyLocalPeerTransportSnapshot(_ snapshot: LocalPeerTransportSnapshot) {
        visibleLocalPeerCount = snapshot.discoveredPeers.count
        visibleLocalPeerRoles = snapshot.availableRemoteRoles
        pendingIncomingRecoveryTransferCount = snapshot.pendingIncomingTransferCount
        pairingCode = snapshot.invitation?.bootstrapCode ?? "Unavailable"
        if snapshot.isAdvertising {
            let peerCount = snapshot.discoveredPeers.count
            let peerSuffix = peerCount == 1 ? "peer endpoint visible" : "peer endpoints visible"
            pairingTransport = "\(snapshot.endpointLabel) • \(peerCount) \(peerSuffix)"
        } else {
            pairingTransport = snapshot.endpointLabel
        }

        if let session = peerTrustSession, session.isActive {
            pairingSessionFingerprint = session.transcriptFingerprint
        } else if let invitation = snapshot.invitation {
            pairingSessionFingerprint = "Invitation \(invitation.fingerprint)"
        } else {
            pairingSessionFingerprint = "Awaiting authenticated local session"
        }
    }

    private func syncPeerTrustFromTransport(reason: String?) async {
        let previousSession = peerTrustSession
        let candidateSession = await localPeerTransport.activeSessionsSnapshot()
            .first(where: { $0.remoteRole.peerKind != nil && $0.isActive })

        if let candidateSession,
           isPeerRevoked(candidateSession.remoteDeviceID) {
            let revocationReason = "Local trust with \(candidateSession.remotePeerName) is revoked on this device. Re-enrollment is required before privileged trust can be restored."
            pendingPeerTrustLossReason = revocationReason
            await localPeerTransport.sealSession(candidateSession.id)
            if previousSession == nil {
                recordFailure(detail: revocationReason)
            }
            return
        }

        let currentSession: PeerTrustSession?
        if let candidateSession {
            if let previousSession,
               shouldReusePeerTrustSession(previousSession, for: candidateSession),
               let existing = await peerTrustCoordinator.currentSession(),
               existing.isActive {
                currentSession = existing
            } else {
                do {
                    currentSession = try await peerTrustCoordinator.establishSession(from: candidateSession)
                } catch {
                    recordFailure(error)
                    return
                }
            }
        } else {
            await peerTrustCoordinator.clearSession()
            currentSession = nil
        }

        peerTrustSession = currentSession
        if let currentSession {
            pairingSessionFingerprint = currentSession.transcriptFingerprint
        }

        let didChangeTrustIdentity = previousSession?.id != currentSession?.id
        let didChangeTrustQuality =
            previousSession?.id == currentSession?.id &&
            (
                previousSession?.trustLevel != currentSession?.trustLevel ||
                previousSession?.proximityEvidence != currentSession?.proximityEvidence ||
                previousSession?.nearbyVerification != currentSession?.nearbyVerification
            )

        guard didChangeTrustIdentity || didChangeTrustQuality else { return }

        if let currentSession {
            pendingPeerTrustLossReason = nil
            schedulePeerTrustExpiry(for: currentSession)
            await persistTrustSessionEstablished(currentSession)
            await refreshDashboard()
            recordEvent(
                .peerPresenceEstablished,
                detail: peerTrustEventDetail(current: currentSession, previous: previousSession)
            )
            return
        }

        if let previousSession {
            peerTrustExpiryTask?.cancel()
            peerTrustExpiryTask = nil
            let didExpire = reason == nil && pendingPeerTrustLossReason == nil
            let lossReason = reason
                ?? pendingPeerTrustLossReason
                ?? "The active peer trust session expired or was removed. Vault policy returns to a sealed posture."
            pendingPeerTrustLossReason = nil
            await persistTrustSessionEnded(
                previousSession,
                didExpire: didExpire,
                reason: lossReason
            )
            await refreshDashboard()
            recordEvent(.peerPresenceLost, detail: lossReason)
        }
    }

    private func shouldReusePeerTrustSession(
        _ session: PeerTrustSession,
        for localSession: AuthenticatedLocalPeerSession
    ) -> Bool {
        session.id == localSession.id &&
        session.transport == localSession.transport &&
        session.capabilities == localSession.remoteCapabilities &&
        session.proximityEvidence == localSession.proximityEvidence &&
        session.trustLevel == localSession.trustLevel &&
        session.nearbyVerification == localSession.nearbyVerification &&
        session.transcriptFingerprint == localSession.transcriptFingerprint &&
        session.peerVerifyingKey == localSession.remoteVerifyingKey &&
        session.appAttested == localSession.remoteAppAttested &&
        session.expiresAt == localSession.expiresAt
    }

    private func peerTrustEventDetail(current: PeerTrustSession, previous: PeerTrustSession?) -> String {
        let expiry = current.expiresAt.formatted(date: .omitted, time: .shortened)
        if previous?.id == current.id, previous?.trustLevel != current.trustLevel {
            return "Upgraded trust with \(current.peerName) to \(current.stateLabel.lowercased()) using \(current.proximityLabel.lowercased()). Session expires at \(expiry)."
        }
        return "Established \(current.stateLabel.lowercased()) trust with \(current.peerName) over \(current.transportLabel) using \(current.proximityLabel.lowercased()). Session expires at \(expiry)."
    }

    private func isPeerRevoked(_ peerDeviceID: String) -> Bool {
        trustLedger.peers.contains { $0.peerDeviceID == peerDeviceID && $0.revokedAt != nil }
    }

    private func syncPendingIncomingRecoveryTransferPreview() async {
        let previousID = pendingIncomingRecoveryTransferPreview?.id
        let nextPreview = await localPeerTransport.peekNextPendingRecoveryTransfer().map {
            $0.document.envelope.approvalPreview(sourceLabel: $0.peerName)
        }
        pendingIncomingRecoveryTransferPreview = nextPreview
        guard previousID != nextPreview?.id else { return }
        guard let nextPreview else { return }
        recordEvent(
            .recoveryTransferAwaitingApproval,
            detail: "Authenticated local recovery transfer from \(nextPreview.sourceLabel) is waiting for explicit local approval before it enters the recovery workspace."
        )
    }

    private func localPeerName() -> String {
        switch role {
        case .authorityPhone:
            return "Authority iPhone"
        case .recoveryPad:
            return "Recovery iPad"
        case .recoveryMac:
            return "Recovery Mac"
        }
    }
}
