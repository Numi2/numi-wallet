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
    var deliveryCurve25519PublicKey: Data
    var taggingCurve25519PublicKey: Data
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
        prover: LocalProver
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
    }

    func bootstrap() async throws -> WalletProfile {
        if let cachedProfile {
            return cachedProfile
        }
        var profile = try await stateStore.load(deviceID: deviceID, role: role)
        if try await migrateLegacyDayDescriptorSecretsIfNeeded(profile: &profile) {
            try await persist(profile)
            return profile
        }
        cachedProfile = profile
        return profile
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

    func unlockVault(peerPresent: Bool, privacyExposureDetected: Bool) async throws -> VaultWalletSnapshot {
        let context = try await authClient.authenticateDeviceOwner(reason: "Unlock Numi vault with local peer present")
        return try await unlockVault(
            peerPresent: peerPresent,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: context
        )
    }

    func unlockVault(
        peerPresent: Bool,
        privacyExposureDetected: Bool,
        authorizationContext context: LAContext
    ) async throws -> VaultWalletSnapshot {
        guard role.isAuthority else { throw WalletError.authorityOnly }
        let profile = try await requireInitializedProfile()
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
        var vault = try openVault(encryptedVault, with: key)
        if try await migrateLegacyVaultDescriptorSecretsIfNeeded(vaultWallet: &vault) {
            var migratedProfile = profile
            unlockedVault = vault
            unlockedVaultKey = key
            try await persistVaultState(into: &migratedProfile, vaultWallet: vault)
        }
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
        peerPresent: Bool,
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
            deliveryCurve25519PublicKey: descriptor.deliveryCurve25519PublicKey,
            taggingCurve25519PublicKey: descriptor.taggingCurve25519PublicKey,
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
        peerPresent: Bool,
        privacyExposureDetected: Bool
    ) async throws -> SpendAuthorization {
        let biometricContext = try await authClient.authenticateBiometric(reason: "Approve Numi spend")
        return try await authorizeSpend(
            draft,
            peerPresent: peerPresent,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
    }

    func authorizeSpend(
        _ draft: SpendDraft,
        peerPresent: Bool,
        privacyExposureDetected: Bool,
        authorizationContext biometricContext: LAContext
    ) async throws -> SpendAuthorization {
        let profile = try await requireInitializedProfile()
        try await keyManager.validateSpendAuthorization(using: biometricContext)
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
            try await persist(profile)
            return ShieldedRefreshReport(
                noteCount: profile.shielded.notes.count,
                spendableNoteCount: 0,
                lastKnownBlockHeight: profile.shielded.pirSync.lastKnownBlockHeight,
                bandwidth: .zero,
                readyForImmediateSpend: false
            )
        }
        let report = try await shieldedStateCoordinator.refresh(
            profile: &profile,
            activeDescriptors: activeDescriptors(from: profile),
            trigger: trigger
        )
        try recalculateBalances(in: &profile)
        try await persist(profile)
        return report
    }

    func submitSpend(
        _ draft: SpendDraft,
        peerPresent: Bool,
        privacyExposureDetected: Bool,
        descriptor: PrivateReceiveDescriptor
    ) async throws -> RelaySubmissionReceipt {
        let biometricContext = try await authClient.authenticateBiometric(reason: "Approve Numi spend")
        return try await submitSpend(
            draft,
            peerPresent: peerPresent,
            privacyExposureDetected: privacyExposureDetected,
            descriptor: descriptor,
            authorizationContext: biometricContext
        )
    }

    func submitSpend(
        _ draft: SpendDraft,
        peerPresent: Bool,
        privacyExposureDetected: Bool,
        descriptor: PrivateReceiveDescriptor,
        authorizationContext biometricContext: LAContext
    ) async throws -> RelaySubmissionReceipt {
        guard configuration.supportsShieldedSpendPipeline else {
            throw WalletError.featureUnavailable("PIR/tag/relay shielded spending")
        }
        let authorization = try await authorizeSpend(
            draft,
            peerPresent: peerPresent,
            privacyExposureDetected: privacyExposureDetected,
            authorizationContext: biometricContext
        )
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
            senderIntroductionPublicKey: tagPlan.introductionPublicKey,
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
        let submission = ShieldedSpendSubmission(
            draft: draft,
            authorization: authorization,
            source: source,
            destinationDescriptorID: descriptor.id,
            outgoingTag: tagPlan.tag,
            isIntroductionPayment: tagPlan.isIntroductionPayment,
            recipientCiphertext: recipientCiphertext,
            feeAuthorization: feeAuthorization,
            createdAt: Date()
        )
        let receipt = try await relayClient.submit(submission)

        if let noteIndex = profile.shielded.notes.firstIndex(where: { $0.id == note.id }) {
            profile.shielded.notes[noteIndex].spendState = .pendingSubmission
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
            if try await migrateLegacyVaultDescriptorSecretsIfNeeded(vaultWallet: &vaultWallet) {
                profile.encryptedVault = try sealVault(vaultWallet, with: key)
            }
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
        let dayWalletData = try JSONEncoder().encode(profile.dayWallet ?? .empty)
        let witness = dayWalletData + (profile.rootPublicIdentity ?? Data())
        let pairedMacAvailable = profile.peers.contains { $0.kind == .mac }
        return try await prover.prove(
            job: LocalProofJob(id: UUID(), label: "Wallet State Check", witness: witness, rounds: 512),
            policy: policy,
            pairedMacAvailable: pairedMacAvailable
        )
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
        let pirStatus: String
        if !configuration.supportsPIRStateUpdates {
            pirStatus = "Inactive for current coin profile"
        } else if let error = profile.shielded.pirSync.lastError {
            pirStatus = error
        } else {
            pirStatus = "Height \(profile.shielded.pirSync.lastKnownBlockHeight) | \(profile.shielded.pirSync.lastBandwidth.totalBytes) B"
        }
        let payReadiness = configuration.supportsShieldedSpendPipeline
            ? (profile.shielded.pirSync.readyForImmediateSpend ? "Ready" : "Refresh needed")
            : "Inactive for current coin profile"
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
            isPrivacyRedacted: !evaluation.sensitiveUIVisible,
            captureDetected: privacyExposureDetected,
            pirStatus: pirStatus,
            lastPIRRefresh: lastRefresh,
            payReadiness: payReadiness,
            lastFeeQuote: lastFeeQuote,
            trackedTagRelationships: profile.shielded.relationships.count,
            trackedNotes: profile.shielded.notes.count
        )
    }

    private func requireInitializedProfile() async throws -> WalletProfile {
        let profile = try await bootstrap()
        guard profile.dayWallet != nil, profile.encryptedVault != nil else {
            throw WalletError.walletNotInitialized
        }
        return profile
    }

    private func persist(_ profile: WalletProfile) async throws {
        var normalizedProfile = profile
        normalizedProfile.version = max(profile.version, 3)
        cachedProfile = normalizedProfile
        try await stateStore.save(normalizedProfile)
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
        let deliveryKey = Curve25519.KeyAgreement.PrivateKey()
        let taggingKey = Curve25519.KeyAgreement.PrivateKey()
        let unsigned = UnsignedReceiveDescriptorPayload(
            id: UUID(),
            tier: tier,
            rotation: rotation,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24),
            aliasHint: aliasHint,
            deliveryCurve25519PublicKey: deliveryKey.publicKey.rawRepresentation,
            taggingCurve25519PublicKey: taggingKey.publicKey.rawRepresentation,
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
            deliveryCurve25519PublicKey: unsigned.deliveryCurve25519PublicKey,
            taggingCurve25519PublicKey: unsigned.taggingCurve25519PublicKey,
            offlineToken: unsigned.offlineToken,
            issuerIdentity: unsigned.issuerIdentity,
            signature: signature
        )
        return DescriptorMaterial(
            descriptor: descriptor,
            secrets: DescriptorPrivateMaterial(
                deliveryKey: deliveryKey.rawRepresentation,
                taggingKey: taggingKey.rawRepresentation
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

    private func migrateLegacyDayDescriptorSecretsIfNeeded(profile: inout WalletProfile) async throws -> Bool {
        guard var dayWallet = profile.dayWallet else { return false }
        let legacySecrets = dayWallet.consumeLegacyDescriptorPrivateKeys()
        guard !legacySecrets.isEmpty else { return false }

        let wrapped = legacySecrets.mapValues { DescriptorPrivateMaterial(deliveryKey: $0, taggingKey: Data()) }
        try await descriptorSecretStore.importSecrets(wrapped, tier: .day)
        profile.dayWallet = dayWallet
        return true
    }

    private func migrateLegacyVaultDescriptorSecretsIfNeeded(vaultWallet: inout VaultWalletSnapshot) async throws -> Bool {
        let legacySecrets = vaultWallet.consumeLegacyDescriptorPrivateKeys()
        guard !legacySecrets.isEmpty else { return false }

        let wrapped = legacySecrets.mapValues { DescriptorPrivateMaterial(deliveryKey: $0, taggingKey: Data()) }
        try await descriptorSecretStore.importSecrets(wrapped, tier: .vault)
        return true
    }
}
