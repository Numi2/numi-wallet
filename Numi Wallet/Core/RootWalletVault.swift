import CryptoKit
import Foundation
import LocalAuthentication

private struct UnsignedReceiveDescriptorPayload: Codable {
    var id: UUID
    var tier: WalletTier
    var rotation: UInt64
    var createdAt: Date
    var expiresAt: Date
    var aliasHint: String?
    var deliveryPublicKey: Data
    var taggingPublicKey: Data
    var offlineToken: Data
    var issuerIdentity: Data
}

private struct RecoverySnapshot: Codable {
    var dayWallet: DayWalletSnapshot
    var vaultWallet: VaultWalletSnapshot
    var shielded: ShieldedWalletSnapshot
    var policy: PolicySnapshot
    var dayDescriptorSecrets: [UUID: DescriptorPrivateMaterial]
    var vaultDescriptorSecrets: [UUID: DescriptorPrivateMaterial]
    var ratchetSecrets: [UUID: RatchetSecretMaterial]
}

private struct DescriptorMaterial {
    var descriptor: PrivateReceiveDescriptor
    var secrets: DescriptorPrivateMaterial
}

actor RootWalletVault {
    private let role: DeviceRole
    private let deviceID: String
    private let stateStore: WalletStateStore
    private let keyManager: SecureEnclaveKeyManager
    private let descriptorSecretStore: DescriptorSecretStore
    private let ratchetSecretStore: RatchetSecretStore
    private let authClient: LocalAuthenticationClient
    private let policyEngine: PolicyEngine
    private let codec: EnvelopeCodec
    private let configuration: RemoteServiceConfiguration
    private let discoveryClient: DiscoveryClient
    private let shieldedStateCoordinator: ShieldedStateCoordinator
    private let dynamicFeeEngine: DynamicFeeEngine
    private let relayClient: RelayClient
    private let prover: LocalProver
    private let tachyonStateAdapter: any TachyonStateAdapter
    private let tachyonTransactionAdapter: any TachyonTransactionAdapter
    private let tachyonProofAdapter: any TachyonProofAdapter
    private let tachyonProofContinuationCoordinator: TachyonProofContinuationCoordinator

    private var cachedProfile: WalletProfile?
    private var unlockedVault: VaultWalletSnapshot?
    private var unlockedVaultKey: SymmetricKey?

    init(
        role: DeviceRole,
        deviceID: String,
        stateStore: WalletStateStore,
        keyManager: SecureEnclaveKeyManager,
        descriptorSecretStore: DescriptorSecretStore,
        ratchetSecretStore: RatchetSecretStore,
        authClient: LocalAuthenticationClient,
        policyEngine: PolicyEngine,
        codec: EnvelopeCodec,
        configuration: RemoteServiceConfiguration,
        discoveryClient: DiscoveryClient,
        shieldedStateCoordinator: ShieldedStateCoordinator,
        dynamicFeeEngine: DynamicFeeEngine,
        relayClient: RelayClient,
        prover: LocalProver,
        tachyonStateAdapter: any TachyonStateAdapter = DefaultTachyonStateAdapter(),
        tachyonTransactionAdapter: any TachyonTransactionAdapter = DefaultTachyonTransactionAdapter(),
        tachyonProofAdapter: any TachyonProofAdapter = RaguTachyonProofAdapter(),
        tachyonProofContinuationCoordinator: TachyonProofContinuationCoordinator = .shared
    ) {
        self.role = role
        self.deviceID = deviceID
        self.stateStore = stateStore
        self.keyManager = keyManager
        self.descriptorSecretStore = descriptorSecretStore
        self.ratchetSecretStore = ratchetSecretStore
        self.authClient = authClient
        self.policyEngine = policyEngine
        self.codec = codec
        self.configuration = configuration
        self.discoveryClient = discoveryClient
        self.shieldedStateCoordinator = shieldedStateCoordinator
        self.dynamicFeeEngine = dynamicFeeEngine
        self.relayClient = relayClient
        self.prover = prover
        self.tachyonStateAdapter = tachyonStateAdapter
        self.tachyonTransactionAdapter = tachyonTransactionAdapter
        self.tachyonProofAdapter = tachyonProofAdapter
        self.tachyonProofContinuationCoordinator = tachyonProofContinuationCoordinator
    }

    func bootstrap() async throws -> WalletProfile {
        if let cachedProfile {
            return cachedProfile
        }
        let profile = try await stateStore.load(deviceID: deviceID, role: role)
        cachedProfile = profile
        return profile
    }

    func prepareTachyonProofContinuation() async {
        await tachyonProofContinuationCoordinator.installHandler { [self] taskIdentifier, progressSink in
            try await runPendingContinuedProcessingProof(
                taskIdentifier: taskIdentifier,
                progressSink: progressSink
            )
        }
    }

    func initializeWallet(dayAlias: String?) async throws -> WalletProfile {
        guard role.isAuthority else { throw WalletError.authorityOnly }

        var profile = try await bootstrap()
        if profile.dayWallet != nil {
            return profile
        }

        let rootPublicKey = try await keyManager.ensureAuthorityPublicKey()
        try await keyManager.ensureSpendAuthorizationToken()
        let vaultWrappingKey = try await keyManager.provisionFreshVaultWrappingKey()

        var dayWallet = DayWalletSnapshot.empty
        dayWallet.alias = dayAlias?.trimmingCharacters(in: .whitespacesAndNewlines)

        let dayDescriptor = try await makeDescriptor(
            tier: .day,
            rotation: 1,
            aliasHint: dayWallet.alias,
            issuerIdentity: rootPublicKey
        )
        dayWallet.activeDescriptor = dayDescriptor.descriptor
        dayWallet.registerDescriptorKey(dayDescriptor.descriptor.id)
        try await descriptorSecretStore.store(
            dayDescriptor.secrets,
            descriptorID: dayDescriptor.descriptor.id,
            tier: .day
        )
        zeroize(dayDescriptor.secrets)

        var vaultWallet = VaultWalletSnapshot.empty
        let vaultDescriptor = try await makeDescriptor(
            tier: .vault,
            rotation: 1,
            aliasHint: nil,
            issuerIdentity: rootPublicKey
        )
        vaultWallet.activeDescriptor = vaultDescriptor.descriptor
        vaultWallet.registerDescriptorKey(vaultDescriptor.descriptor.id)
        try await descriptorSecretStore.store(
            vaultDescriptor.secrets,
            descriptorID: vaultDescriptor.descriptor.id,
            tier: .vault
        )
        zeroize(vaultDescriptor.secrets)

        if configuration.supportsAliasDiscovery, let alias = dayWallet.alias {
            try await discoveryClient.register(alias: alias, descriptor: dayDescriptor.descriptor)
        }

        profile.rootPublicIdentity = rootPublicKey
        profile.dayWallet = dayWallet
        profile.encryptedVault = try sealVault(vaultWallet, with: vaultWrappingKey)
        profile.publicVaultDescriptor = vaultWallet.activeDescriptor
        profile.policy = .default
        profile.lastDayUnlockAt = nil
        profile.lastVaultUnlockAt = nil

        try await persist(profile)
        return profile
    }

    func unlockDayWallet() async throws -> WalletProfile {
        let context = try await authClient.authenticateDeviceOwner(reason: "Unlock Numi day wallet")
        return try await unlockDayWallet(authorizationContext: context)
    }

    func unlockDayWallet(authorizationContext: LAContext) async throws -> WalletProfile {
        guard role.isAuthority else { throw WalletError.authorityOnly }
        _ = authorizationContext
        var profile = try await requireInitializedProfile()
        profile.lastDayUnlockAt = Date()
        try await persist(profile)
        return profile
    }

    func unlockVault(
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool
    ) async throws -> VaultWalletSnapshot {
        let context = try await authClient.authenticateDeviceOwner(reason: "Unlock Numi vault with local peer present")
        return try await unlockVault(
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: context
        )
    }

    func unlockVault(
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool,
        authorizationContext context: LAContext
    ) async throws -> VaultWalletSnapshot {
        guard role.isAuthority else { throw WalletError.authorityOnly }
        let profile = try await requireInitializedProfile()
        let peerPresent = try await validatedPeerPresence(
            session: peerTrustSession,
            assertion: peerPresenceAssertion
        )
        try policyEngine.requireVaultVisibility(
            policy: profile.policy,
            peerPresent: peerPresent,
            vaultAuthSatisfied: true,
            privacyExposureDetected: privacyExposureDetected
        )
        guard let encryptedVault = profile.encryptedVault else {
            throw WalletError.walletNotInitialized
        }

        let key = try await keyManager.loadVaultWrappingKey(using: context)
        let vault = try openVault(encryptedVault, with: key)
        unlockedVault = vault
        unlockedVaultKey = key

        var updated = profile
        updated.lastVaultUnlockAt = Date()
        updated.publicVaultDescriptor = vault.activeDescriptor
        try await persist(updated)
        return vault
    }

    func lockVault() {
        unlockedVault = nil
        unlockedVaultKey = nil
    }

    func rotateDescriptor(
        tier: WalletTier,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool
    ) async throws -> PrivateReceiveDescriptor {
        var profile = try await requireInitializedProfile()
        guard let rootPublic = profile.rootPublicIdentity else {
            throw WalletError.walletNotInitialized
        }

        switch tier {
        case .day:
            guard var dayWallet = profile.dayWallet else { throw WalletError.walletNotInitialized }
            let rotation = (dayWallet.activeDescriptor?.rotation ?? 0) + 1
            let material = try await makeDescriptor(
                tier: .day,
                rotation: rotation,
                aliasHint: dayWallet.alias,
                issuerIdentity: rootPublic
            )
            dayWallet.activeDescriptor = material.descriptor
            dayWallet.registerDescriptorKey(material.descriptor.id)
            try await descriptorSecretStore.store(
                material.secrets,
                descriptorID: material.descriptor.id,
                tier: .day
            )
            zeroize(material.secrets)
            profile.dayWallet = dayWallet
            if configuration.supportsAliasDiscovery, let alias = dayWallet.alias {
                try await discoveryClient.register(alias: alias, descriptor: material.descriptor)
            }
            try await persist(profile)
            return material.descriptor

        case .vault:
            let peerPresent = try await validatedPeerPresence(
                session: peerTrustSession,
                assertion: peerPresenceAssertion
            )
            try policyEngine.requireVaultVisibility(
                policy: profile.policy,
                peerPresent: peerPresent,
                vaultAuthSatisfied: unlockedVault != nil,
                privacyExposureDetected: privacyExposureDetected
            )
            guard var vaultWallet = unlockedVault else { throw WalletError.vaultLocked }
            let rotation = (vaultWallet.activeDescriptor?.rotation ?? 0) + 1
            let material = try await makeDescriptor(
                tier: .vault,
                rotation: rotation,
                aliasHint: nil,
                issuerIdentity: rootPublic
            )
            vaultWallet.activeDescriptor = material.descriptor
            vaultWallet.registerDescriptorKey(material.descriptor.id)
            try await descriptorSecretStore.store(
                material.secrets,
                descriptorID: material.descriptor.id,
                tier: .vault
            )
            zeroize(material.secrets)
            unlockedVault = vaultWallet
            profile.publicVaultDescriptor = material.descriptor
            try await persistVaultState(into: &profile, vaultWallet: vaultWallet)
            return material.descriptor
        }
    }

    func registerDayAlias(_ alias: String) async throws {
        guard configuration.supportsAliasDiscovery else {
            throw WalletError.featureUnavailable("Alias discovery")
        }
        var profile = try await requireInitializedProfile()
        guard var dayWallet = profile.dayWallet, let descriptor = dayWallet.activeDescriptor else {
            throw WalletError.walletNotInitialized
        }
        dayWallet.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.dayWallet = dayWallet
        try await discoveryClient.register(alias: alias, descriptor: descriptor)
        try await persist(profile)
    }

    func resolveAlias(_ alias: String) async throws -> PrivateReceiveDescriptor? {
        guard configuration.supportsAliasDiscovery else {
            throw WalletError.featureUnavailable("Alias discovery")
        }
        guard let descriptor = try await discoveryClient.resolve(alias: alias) else {
            return nil
        }

        let unsigned = UnsignedReceiveDescriptorPayload(
            id: descriptor.id,
            tier: descriptor.tier,
            rotation: descriptor.rotation,
            createdAt: descriptor.createdAt,
            expiresAt: descriptor.expiresAt,
            aliasHint: descriptor.aliasHint,
            deliveryPublicKey: descriptor.deliveryPublicKey,
            taggingPublicKey: descriptor.taggingPublicKey,
            offlineToken: descriptor.offlineToken,
            issuerIdentity: descriptor.issuerIdentity
        )
        let payload = try JSONEncoder().encode(unsigned)
        let valid = try await keyManager.verifyAuthoritySignature(
            signature: descriptor.signature,
            payload: payload,
            publicKey: descriptor.issuerIdentity
        )
        guard valid else { throw WalletError.descriptorVerificationFailed }
        return descriptor
    }

    func authorizeSpend(
        _ draft: SpendDraft,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool
    ) async throws -> SpendAuthorization {
        let biometricContext = try await authClient.authenticateBiometric(reason: "Approve Numi spend")
        return try await authorizeSpend(
            draft,
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
    }

    func authorizeSpend(
        _ draft: SpendDraft,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool,
        authorizationContext biometricContext: LAContext
    ) async throws -> SpendAuthorization {
        let profile = try await requireInitializedProfile()
        try await keyManager.validateSpendAuthorization(using: biometricContext)
        let peerPresent = try await validatedPeerPresence(
            session: peerTrustSession,
            assertion: peerPresenceAssertion
        )
        try policyEngine.requireSpend(
            from: draft.tier,
            policy: profile.policy,
            peerPresent: peerPresent,
            spendAuthSatisfied: true,
            privacyExposureDetected: privacyExposureDetected
        )

        let payload = try JSONEncoder().encode(draft)
        let signature = try await keyManager.signAuthorityPayload(payload)
        return SpendAuthorization(
            draftID: draft.id,
            approvedAt: Date(),
            signature: signature
        )
    }

    @discardableResult
    func refreshShieldedState(trigger: ShieldedRefreshTrigger) async throws -> ShieldedRefreshReport {
        var profile = try await requireInitializedProfile()
        guard configuration.supportsPIRStateUpdates else {
            profile.shielded.pirSync.lastBandwidth = .zero
            profile.shielded.pirSync.readyForImmediateSpend = false
            profile.shielded.pirSync.lastError = nil
            profile.shielded.pirSync.readinessClassification = .stale
            profile.shielded.pirSync.readinessLease = nil
            profile.shielded.pirSync.disputeEvidence = nil
            profile.shielded.pirSync.recentReceipts = []
            try await persist(profile)
            return ShieldedRefreshReport(
                noteCount: profile.shielded.notes.count,
                discoveredNoteCount: profile.shielded.notes.filter { $0.readinessState == .discovered }.count,
                verifiedNoteCount: profile.shielded.notes.filter { $0.readinessState == .verified }.count,
                witnessFreshNoteCount: profile.shielded.notes.filter { $0.readinessState == .witnessFresh }.count,
                spendableNoteCount: 0,
                lastKnownBlockHeight: profile.shielded.pirSync.lastKnownBlockHeight,
                bandwidth: .zero,
                readyForImmediateSpend: false,
                readinessClassification: .stale,
                leaseExpiresAt: nil,
                mismatchCount: profile.shielded.pirSync.mismatchEvents.count,
                deferredMatchCount: 0
            )
        }
        let report = try await shieldedStateCoordinator.refresh(
            profile: &profile,
            activeDescriptors: activeDescriptors(from: profile),
            trigger: trigger,
            checkpoint: { snapshot in
                try await self.persist(snapshot)
            }
        )
        try recalculateBalances(in: &profile)
        try await persist(profile)
        return report
    }

    func submitSpend(
        _ draft: SpendDraft,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool,
        descriptor: PrivateReceiveDescriptor
    ) async throws -> RelaySubmissionReceipt {
        let biometricContext = try await authClient.authenticateBiometric(reason: "Approve Numi spend")
        return try await submitSpend(
            draft,
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            descriptor: descriptor,
            authorizationContext: biometricContext
        )
    }

    func submitSpend(
        _ draft: SpendDraft,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool,
        descriptor: PrivateReceiveDescriptor,
        authorizationContext biometricContext: LAContext
    ) async throws -> RelaySubmissionReceipt {
        guard configuration.supportsShieldedSpendPipeline else {
            throw WalletError.featureUnavailable("PIR/tag/relay shielded spending")
        }
        _ = try await refreshShieldedState(trigger: .preSpend)

        var profile = try await requireInitializedProfile()
        guard let note = selectSpendableNote(
            from: profile.shielded.notes,
            tier: draft.tier,
            minimumValue: draft.amount.minorUnits + draft.maximumFee.minorUnits
        ) else {
            throw WalletError.insufficientFunds
        }
        guard let merklePath = note.merklePath else {
            throw WalletError.missingPIRState
        }

        let tagPlan = try await shieldedStateCoordinator.prepareOutgoingTag(
            profile: &profile,
            alias: descriptor.aliasHint,
            descriptor: descriptor
        )
        let recipientPayload = ShieldedRecipientPayload(
            noteCommitment: noteCommitment(
                draftID: draft.id,
                destinationDescriptorID: descriptor.id,
                amount: draft.amount
            ),
            nullifier: noteNullifier(
                draftID: draft.id,
                destinationDescriptorID: descriptor.id,
                amount: draft.amount
            ),
            amount: draft.amount,
            memo: draft.memo,
            recipientDescriptorID: descriptor.id,
            senderIntroductionEncapsulatedKey: tagPlan.introductionEncapsulatedKey,
            createdAt: Date()
        )
        let recipientCiphertext = try codec.encryptRelayPayload(try JSONEncoder().encode(recipientPayload), to: descriptor)
        let source = ShieldedSpendSource(
            noteID: note.id,
            noteCommitment: note.noteCommitment,
            nullifier: note.nullifier,
            amount: note.amount,
            merklePath: merklePath
        )
        let feeAuthorization = try await dynamicFeeEngine.prepareAuthorization(draft: draft, source: source)
        let witnessRequirements = tachyonStateAdapter.witnessRefreshRequirements(for: [note])
        let sendCapsule = try tachyonTransactionAdapter.makeSendCapsule(
            draft: draft,
            source: source,
            descriptor: descriptor,
            relationshipID: tagPlan.relationshipID,
            outgoingTag: tagPlan.tag,
            isIntroductionPayment: tagPlan.isIntroductionPayment,
            recipientCiphertext: recipientCiphertext,
            feeAuthorization: feeAuthorization,
            network: profile.shielded.network
        )
        let checkpointID = UUID()
        var proofJob = try tachyonProofAdapter.makeSendProofJob(
            capsule: sendCapsule,
            profile: profile,
            witnessRequirements: witnessRequirements,
            lane: .continuedProcessing
        )
        let continuedProcessingTaskIdentifier = TachyonProofContinuationCoordinator.taskIdentifier(for: checkpointID)
        let proofCheckpoint = enqueueProofCheckpoint(
            profile: &profile,
            checkpointID: checkpointID,
            capsule: sendCapsule,
            job: proofJob,
            taskIdentifier: continuedProcessingTaskIdentifier
        )
        try await persist(profile)

        let verifiedProofArtifact: TachyonProofArtifact
        let didScheduleContinuedProcessing = await tachyonProofContinuationCoordinator.submit(
            taskIdentifier: continuedProcessingTaskIdentifier,
            title: "Completing private send proof",
            subtitle: "Sealed Tachyon capsule in progress",
            requestGPU: false
        )

        if didScheduleContinuedProcessing {
            verifiedProofArtifact = try await tachyonProofContinuationCoordinator.awaitResult(for: continuedProcessingTaskIdentifier)
        } else {
            proofJob = try tachyonProofAdapter.makeSendProofJob(
                capsule: sendCapsule,
                profile: profile,
                witnessRequirements: witnessRequirements,
                lane: .foreground
            )
            updateProofCheckpoint(
                profile: &profile,
                checkpointID: proofCheckpoint.id,
                state: .queued,
                job: proofJob,
                taskIdentifier: nil,
                lastError: "Continued processing unavailable; using the foreground proof lane."
            )
            try await persist(profile)
            verifiedProofArtifact = try await runQueuedProofCheckpoint(checkpointID: proofCheckpoint.id)
        }

        profile = try await requireInitializedProfile()
        let authorization = try await authorizeSpend(
            draft,
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
        var submission = ShieldedSpendSubmission(
            draft: draft,
            authorization: authorization,
            source: source,
            destinationDescriptorID: descriptor.id,
            outgoingTag: tagPlan.tag,
            isIntroductionPayment: tagPlan.isIntroductionPayment,
            recipientCiphertext: recipientCiphertext,
            feeAuthorization: feeAuthorization,
            tachyonEnvelope: nil,
            tachyonProofArtifact: verifiedProofArtifact,
            createdAt: Date()
        )
        submission.tachyonEnvelope = try tachyonTransactionAdapter.makeSubmissionEnvelope(
            capsule: sendCapsule,
            proofArtifact: verifiedProofArtifact,
            relayPayload: submission
        )
        let receipt = try await relayClient.submit(submission)

        profile.shielded.pendingProofs.removeAll { $0.id == proofCheckpoint.id }
        if let noteIndex = profile.shielded.notes.firstIndex(where: { $0.id == note.id }) {
            profile.shielded.notes[noteIndex].spendState = .pendingSubmission
        }
        if let relationshipID = tagPlan.relationshipID {
            await shieldedStateCoordinator.finalizeSubmittedOutgoingTag(
                profile: &profile,
                relationshipID: relationshipID,
                isIntroductionPayment: tagPlan.isIntroductionPayment
            )
        }
        profile.shielded.latestFeeQuote = feeAuthorization.quote
        try recalculateBalances(in: &profile)
        try await persist(profile)
        return receipt
    }

    func configureRecoveryQuorum() async throws -> [RecoveryShareEnvelope] {
        let context = try await authClient.authenticateDeviceOwner(reason: "Prepare local-only recovery quorum")
        return try await configureRecoveryQuorum(authorizationContext: context)
    }

    func configureRecoveryQuorum(authorizationContext context: LAContext) async throws -> [RecoveryShareEnvelope] {
        var profile = try await requireInitializedProfile()
        guard let dayWallet = profile.dayWallet, let rootPublicIdentity = profile.rootPublicIdentity else {
            throw WalletError.walletNotInitialized
        }

        var vaultWallet: VaultWalletSnapshot
        if let unlockedVault {
            vaultWallet = unlockedVault
        } else if let encryptedVault = profile.encryptedVault {
            let key = try await keyManager.loadVaultWrappingKey(using: context)
            vaultWallet = try openVault(encryptedVault, with: key)
        } else {
            throw WalletError.walletNotInitialized
        }

        let peers = [
            PairedPeer(
                id: UUID(),
                name: "Mac Sovereign Peer",
                kind: .mac,
                deviceID: "\(deviceID)-mac-peer",
                lastSeenAt: Date(),
                supportsNearbyInteraction: false,
                supportsProofOffload: true
            ),
            PairedPeer(
                id: UUID(),
                name: "iPad Recovery Peer",
                kind: .pad,
                deviceID: "\(deviceID)-pad-peer",
                lastSeenAt: Date(),
                supportsNearbyInteraction: true,
                supportsProofOffload: false
            ),
        ]

        let recoverySnapshot = RecoverySnapshot(
            dayWallet: dayWallet,
            vaultWallet: vaultWallet,
            shielded: profile.shielded,
            policy: profile.policy,
            dayDescriptorSecrets: try await descriptorSecretStore.exportSecrets(for: dayWallet.descriptorKeyIDs, tier: .day),
            vaultDescriptorSecrets: try await descriptorSecretStore.exportSecrets(for: vaultWallet.descriptorKeyIDs, tier: .vault),
            ratchetSecrets: try await ratchetSecretStore.exportSecrets(for: profile.shielded.relationships.map(\.id))
        )
        var snapshotData = try JSONEncoder().encode(recoverySnapshot)
        var recoverySecret = randomData(length: 32)
        defer {
            snapshotData.zeroize()
            recoverySecret.zeroize()
        }
        let packageKey = SymmetricKey(data: recoverySecret)
        let sealedBox = try AES.GCM.seal(snapshotData, using: packageKey)
        let package = RecoveryPackage(
            packageID: UUID(),
            sealedState: sealedBox.combined!,
            createdAt: Date(),
            stateDigest: Data(SHA256.hash(data: snapshotData))
        )

        var fragmentOne = randomData(length: recoverySecret.count)
        var fragmentTwo = xor(fragmentOne, recoverySecret)
        defer {
            fragmentOne.zeroize()
            fragmentTwo.zeroize()
        }
        let shares = zip(peers, [fragmentOne, fragmentTwo]).map { peer, fragment in
            RecoveryShareEnvelope(
                id: UUID(),
                peerName: peer.name,
                peerKind: peer.kind,
                deviceID: peer.deviceID,
                fragment: fragment,
                recoveryPackage: package,
                rootKeyDigest: Data(SHA256.hash(data: rootPublicIdentity)),
                createdAt: Date()
            )
        }

        profile.peers = peers
        profile.recoveryPackage = package
        profile.recoveryPeers = shares.map {
            RecoveryPeerRecord(
                id: $0.id,
                peerName: $0.peerName,
                peerKind: $0.peerKind,
                deviceID: $0.deviceID,
                rootKeyDigest: $0.rootKeyDigest,
                createdAt: $0.createdAt
            )
        }
        try await persist(profile)
        return shares
    }

    func recoverAuthority(from shares: [RecoveryShareEnvelope]) async throws -> WalletProfile {
        let context = try await authClient.authenticateDeviceOwner(reason: "Re-enroll Numi authority from local recovery quorum")
        return try await recoverAuthority(from: shares, authorizationContext: context)
    }

    func recoverAuthority(
        from shares: [RecoveryShareEnvelope],
        authorizationContext: LAContext
    ) async throws -> WalletProfile {
        guard role.isAuthority else { throw WalletError.authorityOnly }
        _ = authorizationContext
        guard shares.count == 2 else { throw WalletError.recoveryQuorumIncomplete }
        try validateRecoveryShares(shares)

        var recoverySecret = xor(shares[0].fragment, shares[1].fragment)
        let package = shares[0].recoveryPackage
        let sealedBox = try AES.GCM.SealedBox(combined: package.sealedState)
        var snapshotData = try AES.GCM.open(sealedBox, using: SymmetricKey(data: recoverySecret))
        defer {
            recoverySecret.zeroize()
            snapshotData.zeroize()
        }
        guard Data(SHA256.hash(data: snapshotData)) == package.stateDigest else {
            throw WalletError.invalidRecoveryPackage
        }
        let snapshot = try JSONDecoder().decode(RecoverySnapshot.self, from: snapshotData)

        let rootPublicKey = try await keyManager.ensureAuthorityPublicKey()
        try await keyManager.ensureSpendAuthorizationToken()
        let vaultWrappingKey = try await keyManager.provisionFreshVaultWrappingKey()

        var recoveredDayWallet = snapshot.dayWallet
        var recoveredVaultWallet = snapshot.vaultWallet
        try await descriptorSecretStore.importSecrets(snapshot.dayDescriptorSecrets, tier: .day)
        try await descriptorSecretStore.importSecrets(snapshot.vaultDescriptorSecrets, tier: .vault)
        try await ratchetSecretStore.importSecrets(snapshot.ratchetSecrets)

        let newDayDescriptor = try await makeDescriptor(
            tier: .day,
            rotation: (recoveredDayWallet.activeDescriptor?.rotation ?? 0) + 1,
            aliasHint: recoveredDayWallet.alias,
            issuerIdentity: rootPublicKey
        )
        recoveredDayWallet.activeDescriptor = newDayDescriptor.descriptor
        recoveredDayWallet.registerDescriptorKey(newDayDescriptor.descriptor.id)
        try await descriptorSecretStore.store(
            newDayDescriptor.secrets,
            descriptorID: newDayDescriptor.descriptor.id,
            tier: .day
        )
        zeroize(newDayDescriptor.secrets)

        let newVaultDescriptor = try await makeDescriptor(
            tier: .vault,
            rotation: (recoveredVaultWallet.activeDescriptor?.rotation ?? 0) + 1,
            aliasHint: nil,
            issuerIdentity: rootPublicKey
        )
        recoveredVaultWallet.activeDescriptor = newVaultDescriptor.descriptor
        recoveredVaultWallet.registerDescriptorKey(newVaultDescriptor.descriptor.id)
        try await descriptorSecretStore.store(
            newVaultDescriptor.secrets,
            descriptorID: newVaultDescriptor.descriptor.id,
            tier: .vault
        )
        zeroize(newVaultDescriptor.secrets)

        var profile = WalletProfile.empty(deviceID: deviceID, role: role)
        profile.rootPublicIdentity = rootPublicKey
        profile.dayWallet = recoveredDayWallet
        profile.encryptedVault = try sealVault(recoveredVaultWallet, with: vaultWrappingKey)
        profile.publicVaultDescriptor = recoveredVaultWallet.activeDescriptor
        profile.shielded = snapshot.shielded
        profile.policy = snapshot.policy
        profile.policy.panicState = .normal
        profile.peers = shares.map {
            PairedPeer(
                id: UUID(),
                name: $0.peerName,
                kind: $0.peerKind,
                deviceID: $0.deviceID,
                lastSeenAt: Date(),
                supportsNearbyInteraction: $0.peerKind == .pad,
                supportsProofOffload: $0.peerKind == .mac
            )
        }
        profile.recoveryPackage = package
        profile.recoveryPeers = shares.map {
            RecoveryPeerRecord(
                id: $0.id,
                peerName: $0.peerName,
                peerKind: $0.peerKind,
                deviceID: $0.deviceID,
                rootKeyDigest: $0.rootKeyDigest,
                createdAt: $0.createdAt
            )
        }

        try await persist(profile)
        return profile
    }

    func panicDestroyLocalUnwrapState() async throws {
        let context = try await authClient.authenticateDeviceOwner(reason: "Destroy local Numi vault unwrap state")
        try await panicDestroyLocalUnwrapState(authorizationContext: context)
    }

    func panicDestroyLocalUnwrapState(authorizationContext: LAContext) async throws {
        _ = authorizationContext
        var profile = try await requireInitializedProfile()
        try await keyManager.destroyLocalVaultWrappingKey()
        profile.policy.panicState = .localUnwrapDestroyed
        unlockedVault = nil
        unlockedVaultKey = nil
        try await persist(profile)
    }

    func suspendSensitiveMemory() {
        unlockedVault = nil
        unlockedVaultKey = nil
        cachedProfile = nil
    }

    func runProof(policy: ProofPolicy) async throws -> LocalProofArtifact {
        let profile = try await requireInitializedProfile()
        let pairedMacAvailable = profile.peers.contains { $0.kind == .mac }
        let proofJob = try tachyonProofAdapter.makeWalletStateCheckJob(
            profile: profile,
            label: "Wallet State Check",
            lane: .foreground
        )
        let proofArtifact = try await prover.prove(
            job: proofJob,
            policy: policy,
            pairedMacAvailable: pairedMacAvailable
        )
        let verifiedProofArtifact = try tachyonProofAdapter.verify(proofArtifact, for: proofJob)
        return tachyonProofAdapter.localArtifact(from: verifiedProofArtifact)
    }

    func resumePendingShieldedSend(
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool
    ) async throws -> RelaySubmissionReceipt {
        let biometricContext = try await authClient.authenticateBiometric(reason: "Approve resumed Numi spend")
        let checkpointID = try await nextActionableProofCheckpointID()
        return try await resumePendingShieldedSend(
            checkpointID: checkpointID,
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
    }

    func resumePendingShieldedSend(
        checkpointID: UUID,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool
    ) async throws -> RelaySubmissionReceipt {
        let biometricContext = try await authClient.authenticateBiometric(reason: "Approve resumed Numi spend")
        return try await resumePendingShieldedSend(
            checkpointID: checkpointID,
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
    }

    func resumePendingShieldedSend(
        checkpointID: UUID,
        peerTrustSession: PeerTrustSession?,
        peerPresenceAssertion: PeerPresenceAssertion?,
        privacyExposureDetected: Bool,
        authorizationContext biometricContext: LAContext
    ) async throws -> RelaySubmissionReceipt {
        guard configuration.supportsShieldedSpendPipeline else {
            throw WalletError.featureUnavailable("PIR/tag/relay shielded spending")
        }

        var profile = try await requireInitializedProfile()
        guard let checkpoint = profile.shielded.pendingProofs.first(where: { $0.id == checkpointID }) else {
            throw WalletError.resumableProofPending("The selected shielded send is no longer queued.")
        }
        guard checkpoint.state != .running else {
            throw WalletError.resumableProofPending("A Tachyon proof is still running. Wait for it to complete before resuming.")
        }

        let proofArtifact: TachyonProofArtifact

        if checkpoint.state == .proofReady, let storedArtifact = checkpoint.artifact {
            do {
                proofArtifact = try tachyonProofAdapter.verify(storedArtifact, for: checkpoint.job)
            } catch {
                let resumedJob = try tachyonProofAdapter.makeSendProofJob(
                    capsule: checkpoint.capsule,
                    profile: profile,
                    witnessRequirements: checkpoint.job.witnessRequirements,
                    lane: .resumed
                )
                updateProofCheckpoint(
                    profile: &profile,
                    checkpointID: checkpointID,
                    state: .queued,
                    job: resumedJob,
                    taskIdentifier: nil,
                    lastError: "Stored proof artifact no longer verifies locally; rerunning in the resumed iPhone lane."
                )
                try await persist(profile)
                proofArtifact = try await runQueuedProofCheckpoint(checkpointID: checkpointID)
            }
        } else {
            let resumedJob = try tachyonProofAdapter.makeSendProofJob(
                capsule: checkpoint.capsule,
                profile: profile,
                witnessRequirements: checkpoint.job.witnessRequirements,
                lane: .resumed
            )
            updateProofCheckpoint(
                profile: &profile,
                checkpointID: checkpointID,
                state: .queued,
                job: resumedJob,
                taskIdentifier: nil,
                lastError: "Resuming pending proof in the foreground on the resumed Tachyon lane."
            )
            try await persist(profile)
            proofArtifact = try await runQueuedProofCheckpoint(checkpointID: checkpointID)
        }

        profile = try await requireInitializedProfile()
        guard let checkpointIndex = profile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) else {
            throw WalletError.resumableProofPending("The pending shielded send disappeared before authorization.")
        }

        let capsule = profile.shielded.pendingProofs[checkpointIndex].capsule
        let authorization = try await authorizeSpend(
            capsule.draft,
            peerTrustSession: peerTrustSession,
            peerPresenceAssertion: peerPresenceAssertion,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
        var submission = ShieldedSpendSubmission(
            draft: capsule.draft,
            authorization: authorization,
            source: capsule.source,
            destinationDescriptorID: capsule.destinationDescriptorID,
            outgoingTag: capsule.outgoingTag,
            isIntroductionPayment: capsule.isIntroductionPayment,
            recipientCiphertext: capsule.recipientCiphertext,
            feeAuthorization: capsule.feeAuthorization,
            tachyonEnvelope: nil,
            tachyonProofArtifact: proofArtifact,
            createdAt: Date()
        )
        submission.tachyonEnvelope = try tachyonTransactionAdapter.makeSubmissionEnvelope(
            capsule: capsule,
            proofArtifact: proofArtifact,
            relayPayload: submission
        )
        let receipt = try await relayClient.submit(submission)

        profile.shielded.pendingProofs.removeAll { $0.id == checkpointID }
        if let noteIndex = profile.shielded.notes.firstIndex(where: { $0.id == capsule.source.noteID }) {
            profile.shielded.notes[noteIndex].spendState = .pendingSubmission
        }
        if let relationshipID = capsule.relationshipID {
            await shieldedStateCoordinator.finalizeSubmittedOutgoingTag(
                profile: &profile,
                relationshipID: relationshipID,
                isIntroductionPayment: capsule.isIntroductionPayment
            )
        }
        profile.shielded.latestFeeQuote = capsule.feeAuthorization.quote
        try recalculateBalances(in: &profile)
        try await persist(profile)
        return receipt
    }

    func discardPendingShieldedSend(checkpointID: UUID) async throws {
        guard configuration.supportsShieldedSpendPipeline else {
            throw WalletError.featureUnavailable("PIR/tag/relay shielded spending")
        }

        var profile = try await requireInitializedProfile()
        guard let checkpointIndex = profile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) else {
            throw WalletError.resumableProofPending("The selected shielded send is no longer queued.")
        }

        let checkpoint = profile.shielded.pendingProofs[checkpointIndex]
        guard checkpoint.state != .running else {
            throw WalletError.resumableProofPending("A Tachyon proof is still running. Wait for it to complete before discarding.")
        }

        if let relationshipID = checkpoint.capsule.relationshipID {
            try await shieldedStateCoordinator.discardPreparedOutgoingTag(
                profile: &profile,
                relationshipID: relationshipID,
                isIntroductionPayment: checkpoint.capsule.isIntroductionPayment
            )
        }

        profile.shielded.pendingProofs.remove(at: checkpointIndex)
        try await persist(profile)
    }

    func runPendingContinuedProcessingProof(
        taskIdentifier: String,
        progressSink: @escaping @Sendable (TachyonProofProgress) async -> Void
    ) async throws -> TachyonProofArtifact {
        var profile = try await requireInitializedProfile()
        guard let checkpointIndex = profile.shielded.pendingProofs.firstIndex(where: { $0.taskIdentifier == taskIdentifier }) else {
            throw WalletError.resumableProofPending("No persisted proof checkpoint matches \(taskIdentifier).")
        }
        return try await executeProofCheckpoint(
            profile: &profile,
            checkpointIndex: checkpointIndex,
            progressSink: progressSink
        )
    }

    private func runQueuedProofCheckpoint(checkpointID: UUID) async throws -> TachyonProofArtifact {
        var profile = try await requireInitializedProfile()
        guard let checkpointIndex = profile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) else {
            throw WalletError.resumableProofPending("No persisted proof checkpoint matches \(checkpointID.uuidString).")
        }
        return try await executeProofCheckpoint(profile: &profile, checkpointIndex: checkpointIndex)
    }

    private func executeProofCheckpoint(
        profile: inout WalletProfile,
        checkpointIndex: Int,
        progressSink: @escaping @Sendable (TachyonProofProgress) async -> Void = { _ in }
    ) async throws -> TachyonProofArtifact {
        var checkpoint = profile.shielded.pendingProofs[checkpointIndex]
        checkpoint.state = .running
        checkpoint.progress = []
        checkpoint.artifact = nil
        checkpoint.lastError = nil
        checkpoint.updatedAt = Date()
        profile.shielded.pendingProofs[checkpointIndex] = checkpoint
        try await persist(profile)

        let pairedMacAvailable = profile.peers.contains { $0.kind == .mac }
        let checkpointID = checkpoint.id

        do {
            let artifact = try await prover.prove(
                job: checkpoint.job,
                policy: profile.policy.proofPolicy,
                pairedMacAvailable: pairedMacAvailable
            ) { [self] progress in
                await recordProofCheckpointProgress(checkpointID: checkpointID, progress: progress)
                await progressSink(progress)
            }
            let verifiedArtifact = try tachyonProofAdapter.verify(artifact, for: checkpoint.job)

            var refreshedProfile = try await requireInitializedProfile()
            guard let refreshedIndex = refreshedProfile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) else {
                throw WalletError.resumableProofPending("Proof checkpoint disappeared before verification completed.")
            }

            refreshedProfile.shielded.pendingProofs[refreshedIndex].state = .proofReady
            refreshedProfile.shielded.pendingProofs[refreshedIndex].progress = verifiedArtifact.progress
            refreshedProfile.shielded.pendingProofs[refreshedIndex].artifact = verifiedArtifact
            refreshedProfile.shielded.pendingProofs[refreshedIndex].lastError = nil
            refreshedProfile.shielded.pendingProofs[refreshedIndex].updatedAt = verifiedArtifact.completedAt
            try await persist(refreshedProfile)
            return verifiedArtifact
        } catch is CancellationError {
            var refreshedProfile = try await requireInitializedProfile()
            if let refreshedIndex = refreshedProfile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) {
                refreshedProfile.shielded.pendingProofs[refreshedIndex].state = .expired
                refreshedProfile.shielded.pendingProofs[refreshedIndex].lastError = "Continued processing expired before spend authorization. The sealed send capsule remains resumable."
                refreshedProfile.shielded.pendingProofs[refreshedIndex].updatedAt = Date()
                try await persist(refreshedProfile)
            }
            throw WalletError.resumableProofPending("Continued processing expired. The sealed send capsule can be resumed when the app returns to the foreground.")
        } catch {
            var refreshedProfile = try await requireInitializedProfile()
            if let refreshedIndex = refreshedProfile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) {
                refreshedProfile.shielded.pendingProofs[refreshedIndex].state = .failed
                refreshedProfile.shielded.pendingProofs[refreshedIndex].lastError = error.localizedDescription
                refreshedProfile.shielded.pendingProofs[refreshedIndex].updatedAt = Date()
                try await persist(refreshedProfile)
            }
            throw error
        }
    }

    private func recordProofCheckpointProgress(checkpointID: UUID, progress: TachyonProofProgress) async {
        guard var profile = try? await bootstrap(),
              let checkpointIndex = profile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID })
        else {
            return
        }

        profile.shielded.pendingProofs[checkpointIndex].state = .running
        profile.shielded.pendingProofs[checkpointIndex].progress.append(progress)
        profile.shielded.pendingProofs[checkpointIndex].updatedAt = progress.updatedAt
        try? await persist(profile)
    }

    private func validatedPeerPresence(
        session: PeerTrustSession?,
        assertion: PeerPresenceAssertion?
    ) async throws -> Bool {
        guard let session else { return false }
        guard session.isActive else { return false }
        guard let assertion else { return false }
        guard assertion.isActive, assertion.matches(session: session) else {
            throw WalletError.invalidPeerPresenceAssertion
        }

        let payload = try JSONEncoder().encode(assertion.unsignedAssertion())
        let isValid = try await keyManager.verifyPeerSignature(
            signature: assertion.signature,
            payload: payload,
            publicKey: session.peerVerifyingKey
        )
        guard isValid else {
            throw WalletError.invalidPeerPresenceAssertion
        }
        return true
    }

    func dashboard(
        peerPresent: Bool,
        lastProofVenue: String,
        privacyExposureDetected: Bool
    ) async throws -> WalletDashboardState {
        let profile = try await bootstrap()
        let evaluation = policyEngine.evaluate(
            policy: profile.policy,
            peerPresent: peerPresent,
            vaultAuthSatisfied: unlockedVault != nil,
            privacyExposureDetected: privacyExposureDetected
        )
        let dayBalance = evaluation.dayVisible
            ? (profile.dayWallet?.balance.formatted() ?? MoneyAmount.zero.formatted())
            : "Redacted"
        let vaultBalance = evaluation.vaultVisible ? unlockedVault?.balance.formatted() : nil
        let lastRefresh = configuration.supportsPIRStateUpdates
            ? (profile.shielded.pirSync.lastRefreshAt?.formatted(date: .omitted, time: .shortened) ?? "Never")
            : "Inactive"
        let readinessClassification = profile.shielded.pirSync.readinessClassification
        let trustedHeight = profile.shielded.pirSync.readinessLease?.trustedBlockHeight ?? profile.shielded.pirSync.lastKnownBlockHeight
        let pirStatus: String
        if !configuration.supportsPIRStateUpdates {
            pirStatus = "Inactive for current coin profile"
        } else if let error = profile.shielded.pirSync.lastError {
            pirStatus = "\(readinessClassification.displayName) | H\(trustedHeight) | \(error)"
        } else {
            pirStatus = "\(readinessClassification.displayName) | H\(trustedHeight) | \(profile.shielded.pirSync.lastBandwidth.totalBytes) B"
        }
        let payReadiness = configuration.supportsShieldedSpendPipeline
            ? spendReadinessLabel(for: profile)
            : "Inactive for current coin profile"
        let relationshipPosture = relationshipPostureLabel(for: profile.shielded.relationships)
        let receiveSummary = receiveSummary(for: profile.shielded)
        let proofQueueStatus = proofQueueStatusLabel(for: profile.shielded.pendingProofs)
        let pendingShieldedSends = pendingShieldedSendSummaries(for: profile)
        let lastFeeQuote = configuration.supportsDynamicFeeMarkets
            ? (profile.shielded.latestFeeQuote.map { quote in
                "\(quote.recommendedFee.formatted()) @ \(quote.marketRatePerWeight)"
            } ?? "No fee quote")
            : "Static or coin-defined fees"
        return WalletDashboardState(
            role: role,
            isInitialized: profile.dayWallet != nil,
            isVaultUnlocked: unlockedVault != nil,
            isPeerPresent: peerPresent,
            dayBalance: dayBalance,
            vaultBalance: vaultBalance,
            dayDescriptorFingerprint: evaluation.dayVisible ? profile.dayWallet?.activeDescriptor?.fingerprint : "Redacted",
            vaultDescriptorFingerprint: evaluation.vaultVisible ? unlockedVault?.activeDescriptor?.fingerprint : nil,
            proofVenue: lastProofVenue,
            proofQueueStatus: proofQueueStatus,
            pendingShieldedSends: pendingShieldedSends,
            isPrivacyRedacted: !evaluation.sensitiveUIVisible,
            captureDetected: privacyExposureDetected,
            pirStatus: pirStatus,
            lastPIRRefresh: lastRefresh,
            payReadiness: payReadiness,
            relationshipPosture: relationshipPosture,
            receiveSummary: receiveSummary,
            lastFeeQuote: lastFeeQuote,
            trackedTagRelationships: profile.shielded.relationships.count,
            trackedNotes: profile.shielded.notes.count
        )
    }

    private func spendReadinessLabel(for profile: WalletProfile) -> String {
        switch profile.shielded.pirSync.readinessClassification {
        case .ready:
            if profile.shielded.pirSync.readyForImmediateSpend {
                return "Ready"
            }
            return profile.shielded.notes.isEmpty ? "No tracked notes" : "No spendable notes"
        case .stale:
            return "Quick private refresh required"
        case .degraded:
            return "Refresh degraded"
        case .disputed:
            return "Disputed; blocked"
        }
    }

    private func relationshipPostureLabel(for relationships: [TagRelationshipSnapshot]) -> String {
        guard !relationships.isEmpty else {
            return "No tracked relationships"
        }
        let newCount = relationships.filter {
            $0.state == .bootstrapPending || $0.state == .introductionSent || $0.state == .introductionReceived
        }.count
        let activeCount = relationships.filter { $0.state == .activeBidirectional }.count
        let staleCount = relationships.filter { $0.state == .stale }.count
        let rotatingCount = relationships.filter { $0.state == .rotationPending }.count
        let revokedCount = relationships.filter { $0.state == .revoked }.count

        var segments = [
            "New \(newCount)",
            "Active \(activeCount)",
            "Stale \(staleCount)",
            "Rotating \(rotatingCount)"
        ]
        if revokedCount > 0 {
            segments.append("Revoked \(revokedCount)")
        }
        return segments.joined(separator: " | ")
    }

    private func receiveSummary(for shielded: ShieldedWalletSnapshot) -> ShieldedReceiveStatusSummary {
        ShieldedReceiveStatusSummary(
            discoveredNoteCount: shielded.notes.filter { $0.readinessState == .discovered }.count,
            verifiedNoteCount: shielded.notes.filter { $0.readinessState == .verified }.count,
            witnessFreshNoteCount: shielded.notes.filter { $0.readinessState == .witnessFresh }.count,
            spendableNoteCount: shielded.notes.filter(\.isSpendable).count,
            pendingJournalCount: shielded.inboxJournal.filter {
                $0.stage == .matchReceived || $0.stage == .payloadDecrypted || $0.stage == .payloadValidated
            }.count,
            deferredJournalCount: shielded.inboxJournal.filter { $0.stage == .deferred }.count,
            failedJournalCount: shielded.inboxJournal.filter { $0.stage == .failed }.count
        )
    }

    private func proofQueueStatusLabel(for checkpoints: [TachyonProofCheckpoint]) -> String {
        guard !checkpoints.isEmpty else {
            return "Idle"
        }

        let runningCount = checkpoints.filter { $0.state == .running }.count
        let queuedCount = checkpoints.filter { $0.state == .queued }.count
        let readyCount = checkpoints.filter { $0.state == .proofReady }.count
        let expiredCount = checkpoints.filter { $0.state == .expired }.count
        let failedCount = checkpoints.filter { $0.state == .failed }.count

        var segments: [String] = []
        if runningCount > 0 {
            segments.append("Running \(runningCount)")
        }
        if queuedCount > 0 {
            segments.append("Queued \(queuedCount)")
        }
        if readyCount > 0 {
            segments.append("Ready \(readyCount)")
        }
        if expiredCount > 0 {
            segments.append("Resumable \(expiredCount)")
        }
        if failedCount > 0 {
            segments.append("Failed \(failedCount)")
        }

        return segments.isEmpty ? "Idle" : segments.joined(separator: " | ")
    }

    private func pendingShieldedSendSummaries(for profile: WalletProfile) -> [PendingShieldedSendSummary] {
        let relationshipsByID = Dictionary(uniqueKeysWithValues: profile.shielded.relationships.map { ($0.id, $0) })
        return profile.shielded.pendingProofs
            .map { checkpoint in
                let trimmedMemo = checkpoint.capsule.draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                let alias = (
                    checkpoint.capsule.relationshipID
                        .flatMap { relationshipsByID[$0]?.alias }
                )?.trimmingCharacters(in: .whitespacesAndNewlines)
                let counterpartyLabel: String
                if let alias, !alias.isEmpty {
                    counterpartyLabel = "To \(alias)"
                } else if !trimmedMemo.isEmpty {
                    counterpartyLabel = trimmedMemo
                } else {
                    counterpartyLabel = "Shielded send \(checkpoint.capsule.draft.id.uuidString.prefix(8))"
                }
                let memoLabel = !trimmedMemo.isEmpty && counterpartyLabel != trimmedMemo ? trimmedMemo : nil
                return PendingShieldedSendSummary(
                    id: checkpoint.id,
                    counterpartyLabel: counterpartyLabel,
                    memoLabel: memoLabel,
                    amount: checkpoint.capsule.draft.amount.formatted(),
                    tierLabel: checkpoint.capsule.draft.tier.displayName,
                    state: checkpoint.state,
                    stateLabel: proofQueueStateLabel(for: checkpoint.state),
                    laneLabel: proofLaneLabel(for: checkpoint.job.lane),
                    updatedAt: checkpoint.updatedAt,
                    updatedAtLabel: checkpoint.updatedAt.formatted(date: .omitted, time: .shortened),
                    detail: proofQueueDetail(for: checkpoint),
                    actionLabel: proofQueueActionLabel(for: checkpoint.state),
                    canDiscard: checkpoint.state != .running,
                )
            }
            .sorted { lhs, rhs in
                let leftPriority = proofQueueDisplayPriority(for: lhs.state)
                let rightPriority = proofQueueDisplayPriority(for: rhs.state)
                if leftPriority == rightPriority {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return leftPriority < rightPriority
            }
    }

    private func latestActionableProofCheckpoint(from checkpoints: [TachyonProofCheckpoint]) -> TachyonProofCheckpoint? {
        checkpoints
            .compactMap { checkpoint -> (priority: Int, checkpoint: TachyonProofCheckpoint)? in
                guard let priority = actionablePriority(for: checkpoint.state) else {
                    return nil
                }
                return (priority, checkpoint)
            }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.checkpoint.updatedAt > rhs.checkpoint.updatedAt
                }
                return lhs.priority < rhs.priority
            }
            .first?
            .checkpoint
    }

    private func nextActionableProofCheckpointID() async throws -> UUID {
        let profile = try await requireInitializedProfile()
        guard let checkpoint = latestActionableProofCheckpoint(from: profile.shielded.pendingProofs) else {
            if profile.shielded.pendingProofs.contains(where: { $0.state == .running }) {
                throw WalletError.resumableProofPending("A Tachyon proof is still running. Wait for it to complete before resuming.")
            }
            throw WalletError.resumableProofPending("No resumable shielded send is currently queued.")
        }
        return checkpoint.id
    }

    private func actionablePriority(for state: TachyonProofCheckpointState) -> Int? {
        switch state {
        case .proofReady:
            return 0
        case .expired:
            return 1
        case .queued:
            return 2
        case .failed:
            return 3
        case .running:
            return nil
        }
    }

    private func proofQueueDisplayPriority(for state: TachyonProofCheckpointState) -> Int {
        switch state {
        case .proofReady:
            return 0
        case .running:
            return 1
        case .expired:
            return 2
        case .queued:
            return 3
        case .failed:
            return 4
        }
    }

    private func proofQueueActionLabel(for state: TachyonProofCheckpointState) -> String? {
        switch state {
        case .proofReady:
            return "Authorize Send"
        case .expired:
            return "Resume Proof"
        case .queued:
            return "Start Proof"
        case .failed:
            return "Retry Proof"
        case .running:
            return nil
        }
    }

    private func proofQueueStateLabel(for state: TachyonProofCheckpointState) -> String {
        switch state {
        case .queued:
            return "Queued"
        case .running:
            return "Running"
        case .proofReady:
            return "Ready"
        case .expired:
            return "Resumable"
        case .failed:
            return "Failed"
        }
    }

    private func proofLaneLabel(for lane: TachyonProofLane) -> String {
        switch lane {
        case .foreground:
            return "Foreground"
        case .continuedProcessing:
            return "Continued"
        case .resumed:
            return "Resumed"
        }
    }

    private func proofQueueDetail(for checkpoint: TachyonProofCheckpoint) -> String {
        if checkpoint.state == .proofReady {
            return "Local proof verified. Awaiting biometric spend approval and relay submission."
        }

        if let progress = checkpoint.progress.last {
            let percent = Int((progress.fractionCompleted * 100).rounded())
            if let detail = progress.detail, !detail.isEmpty {
                return "\(proofProgressLabel(for: progress.phase)) • \(percent)% • \(detail)"
            }
            return "\(proofProgressLabel(for: progress.phase)) • \(percent)% complete"
        }

        if let lastError = checkpoint.lastError, !lastError.isEmpty {
            return lastError
        }

        switch checkpoint.state {
        case .queued:
            return "Sealed send capsule persisted and waiting for the next proof lane."
        case .running:
            return "Proof lane is actively processing this sealed send capsule."
        case .expired:
            return "Continued processing expired before authorization. Resume on the foreground Tachyon lane."
        case .failed:
            return "The last proof attempt failed before authorization. Retry from the persisted capsule."
        case .proofReady:
            return "Local proof verified. Awaiting biometric spend approval and relay submission."
        }
    }

    private func proofProgressLabel(for phase: TachyonProofProgressPhase) -> String {
        switch phase {
        case .prepared:
            return "Prepared"
        case .witnessBound:
            return "Witness Bound"
        case .accumulated:
            return "Accumulated"
        case .compressed:
            return "Compressed"
        case .verified:
            return "Verified"
        }
    }

    private func enqueueProofCheckpoint(
        profile: inout WalletProfile,
        checkpointID: UUID,
        capsule: TachyonSendCapsule,
        job: TachyonProofJob,
        taskIdentifier: String?
    ) -> TachyonProofCheckpoint {
        profile.shielded.pendingProofs.removeAll { $0.capsule.draft.id == capsule.draft.id }

        let checkpoint = TachyonProofCheckpoint(
            id: checkpointID,
            taskIdentifier: taskIdentifier,
            state: .queued,
            capsule: capsule,
            job: job,
            progress: [],
            artifact: nil,
            lastError: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        profile.shielded.pendingProofs.append(checkpoint)
        return checkpoint
    }

    private func updateProofCheckpoint(
        profile: inout WalletProfile,
        checkpointID: UUID,
        state: TachyonProofCheckpointState,
        job: TachyonProofJob,
        taskIdentifier: String?,
        lastError: String?
    ) {
        guard let checkpointIndex = profile.shielded.pendingProofs.firstIndex(where: { $0.id == checkpointID }) else {
            return
        }

        profile.shielded.pendingProofs[checkpointIndex].state = state
        profile.shielded.pendingProofs[checkpointIndex].job = job
        profile.shielded.pendingProofs[checkpointIndex].taskIdentifier = taskIdentifier
        profile.shielded.pendingProofs[checkpointIndex].progress = []
        profile.shielded.pendingProofs[checkpointIndex].artifact = nil
        profile.shielded.pendingProofs[checkpointIndex].lastError = lastError
        profile.shielded.pendingProofs[checkpointIndex].updatedAt = Date()
    }

    private func requireInitializedProfile() async throws -> WalletProfile {
        let profile = try await bootstrap()
        guard profile.dayWallet != nil, profile.encryptedVault != nil else {
            throw WalletError.walletNotInitialized
        }
        return profile
    }

    private func persist(_ profile: WalletProfile) async throws {
        cachedProfile = profile
        try await stateStore.save(profile)
    }

    private func persistVaultState(into profile: inout WalletProfile, vaultWallet: VaultWalletSnapshot) async throws {
        guard let unlockedVaultKey else { throw WalletError.vaultLocked }
        profile.encryptedVault = try sealVault(vaultWallet, with: unlockedVaultKey)
        profile.publicVaultDescriptor = vaultWallet.activeDescriptor
        try await persist(profile)
    }

    private func makeDescriptor(
        tier: WalletTier,
        rotation: UInt64,
        aliasHint: String?,
        issuerIdentity: Data
    ) async throws -> DescriptorMaterial {
        let deliveryKey = try XWingMLKEM768X25519.PrivateKey()
        let taggingKey = try XWingMLKEM768X25519.PrivateKey()
        let unsigned = UnsignedReceiveDescriptorPayload(
            id: UUID(),
            tier: tier,
            rotation: rotation,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24),
            aliasHint: aliasHint,
            deliveryPublicKey: deliveryKey.publicKey.rawRepresentation,
            taggingPublicKey: taggingKey.publicKey.rawRepresentation,
            offlineToken: randomData(length: 32),
            issuerIdentity: issuerIdentity
        )
        let payload = try JSONEncoder().encode(unsigned)
        let signature = try await keyManager.signAuthorityPayload(payload)
        let descriptor = PrivateReceiveDescriptor(
            id: unsigned.id,
            tier: unsigned.tier,
            rotation: unsigned.rotation,
            createdAt: unsigned.createdAt,
            expiresAt: unsigned.expiresAt,
            aliasHint: unsigned.aliasHint,
            deliveryPublicKey: unsigned.deliveryPublicKey,
            taggingPublicKey: unsigned.taggingPublicKey,
            offlineToken: unsigned.offlineToken,
            issuerIdentity: unsigned.issuerIdentity,
            signature: signature
        )
        return DescriptorMaterial(
            descriptor: descriptor,
            secrets: DescriptorPrivateMaterial(
                deliveryKey: deliveryKey.integrityCheckedRepresentation,
                taggingKey: taggingKey.integrityCheckedRepresentation
            )
        )
    }

    private func sealVault(_ vault: VaultWalletSnapshot, with key: SymmetricKey) throws -> EncryptedVaultBlob {
        let payload = try JSONEncoder().encode(vault)
        let sealed = try AES.GCM.seal(payload, using: key)
        guard let combined = sealed.combined else { throw WalletError.corruptedState }
        return EncryptedVaultBlob(ciphertext: combined, updatedAt: Date())
    }

    private func openVault(_ blob: EncryptedVaultBlob, with key: SymmetricKey) throws -> VaultWalletSnapshot {
        let sealedBox = try AES.GCM.SealedBox(combined: blob.ciphertext)
        let data = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(VaultWalletSnapshot.self, from: data)
    }

    private func randomData(length: Int) -> Data {
        Data((0..<length).map { _ in UInt8.random(in: .min ... .max) })
    }

    private func xor(_ lhs: Data, _ rhs: Data) -> Data {
        Data(zip(lhs, rhs).map(^))
    }

    private func validateRecoveryShares(_ shares: [RecoveryShareEnvelope]) throws {
        guard shares.count == 2 else { throw WalletError.recoveryQuorumIncomplete }

        let kinds = Set(shares.map(\.peerKind))
        guard kinds == Set(PeerKind.allCases) else {
            throw WalletError.invalidRecoveryPackage
        }

        guard shares.map(\.deviceID).count == Set(shares.map(\.deviceID)).count else {
            throw WalletError.invalidRecoveryPackage
        }

        guard let first = shares.first else { throw WalletError.invalidRecoveryPackage }
        for share in shares.dropFirst() {
            guard share.recoveryPackage.packageID == first.recoveryPackage.packageID,
                  share.recoveryPackage.sealedState == first.recoveryPackage.sealedState,
                  share.recoveryPackage.stateDigest == first.recoveryPackage.stateDigest,
                  share.rootKeyDigest == first.rootKeyDigest else {
                throw WalletError.invalidRecoveryPackage
            }
        }
    }

    private func activeDescriptors(from profile: WalletProfile) -> [PrivateReceiveDescriptor] {
        [
            profile.dayWallet?.activeDescriptor,
            profile.publicVaultDescriptor,
        ]
        .compactMap { $0 }
    }

    private func selectSpendableNote(
        from notes: [ShieldedNoteWitness],
        tier: WalletTier,
        minimumValue: Int64
    ) -> ShieldedNoteWitness? {
        notes
            .filter { $0.tier == tier && $0.isSpendable && $0.amount.minorUnits >= minimumValue }
            .sorted { $0.amount.minorUnits < $1.amount.minorUnits }
            .first
    }

    private func recalculateBalances(in profile: inout WalletProfile) throws {
        let dayTotal = profile.shielded.notes
            .filter { $0.tier == .day && $0.spendState == .ready }
            .reduce(Int64.zero) { $0 + $1.amount.minorUnits }
        let vaultTotal = profile.shielded.notes
            .filter { $0.tier == .vault && $0.spendState == .ready }
            .reduce(Int64.zero) { $0 + $1.amount.minorUnits }

        if var dayWallet = profile.dayWallet {
            dayWallet.balance = MoneyAmount(minorUnits: dayTotal, currencyCode: "NUMI")
            profile.dayWallet = dayWallet
        }
        if let unlockedVault {
            var updatedVault = unlockedVault
            updatedVault.balance = MoneyAmount(minorUnits: vaultTotal, currencyCode: "NUMI")
            self.unlockedVault = updatedVault
            if let unlockedVaultKey {
                profile.encryptedVault = try sealVault(updatedVault, with: unlockedVaultKey)
            }
        }
    }

    private func noteCommitment(
        draftID: UUID,
        destinationDescriptorID: UUID,
        amount: MoneyAmount
    ) -> Data {
        let amountData = withUnsafeBytes(of: amount.minorUnits.bigEndian) { Data($0) }
        return Data(
            SHA256.hash(
                data: Data(draftID.uuidString.utf8)
                    + Data(destinationDescriptorID.uuidString.utf8)
                    + amountData
            )
        )
    }

    private func noteNullifier(
        draftID: UUID,
        destinationDescriptorID: UUID,
        amount: MoneyAmount
    ) -> Data {
        let amountData = withUnsafeBytes(of: amount.minorUnits.bigEndian) { Data($0) }
        return Data(
            SHA256.hash(
                data: Data("numi.nullifier".utf8)
                    + Data(draftID.uuidString.utf8)
                    + Data(destinationDescriptorID.uuidString.utf8)
                    + amountData
            )
        )
    }

    private func zeroize(_ material: DescriptorPrivateMaterial) {
        var delivery = material.deliveryKey
        var tagging = material.taggingKey
        delivery.zeroize()
        tagging.zeroize()
    }
}
