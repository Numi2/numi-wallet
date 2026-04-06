import Foundation

actor RecoveryTransferCoordinator {
    private let keyManager: SecureEnclaveKeyManager
    private let localDeviceID: String
    private let encoder = JSONEncoder()

    init(keyManager: SecureEnclaveKeyManager, localDeviceID: String) {
        self.keyManager = keyManager
        self.localDeviceID = localDeviceID
    }

    func makeEnvelope(
        payload: RecoveryTransferPayload,
        senderRole: DeviceRole,
        recipientRole: DeviceRole,
        trustSession: PeerTrustSession?,
        ttl: TimeInterval = 10 * 60
    ) async throws -> RecoveryTransferEnvelope {
        let activeTrustSession = trustSession?.isActive == true ? trustSession : nil
        try await validatePayloadBinding(
            payload,
            senderRole: senderRole,
            recipientRole: recipientRole,
            trustSessionFingerprint: activeTrustSession?.transcriptFingerprint,
            activeTrustSession: activeTrustSession
        )
        let unsigned = UnsignedRecoveryTransferEnvelope(
            id: UUID(),
            senderRole: senderRole,
            senderDeviceID: localDeviceID,
            senderVerifyingKey: try await keyManager.ensurePeerIdentityPublicKey(),
            recipientRole: recipientRole,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(ttl),
            trustSessionFingerprint: activeTrustSession?.transcriptFingerprint,
            payload: payload
        )
        let payloadData = try encoder.encode(unsigned)
        let signature = try await keyManager.signPeerPayload(payloadData)
        return RecoveryTransferEnvelope(
            id: unsigned.id,
            senderRole: unsigned.senderRole,
            senderDeviceID: unsigned.senderDeviceID,
            senderVerifyingKey: unsigned.senderVerifyingKey,
            recipientRole: unsigned.recipientRole,
            createdAt: unsigned.createdAt,
            expiresAt: unsigned.expiresAt,
            trustSessionFingerprint: unsigned.trustSessionFingerprint,
            payload: unsigned.payload,
            signature: signature
        )
    }

    func resolvePayload(
        from document: RecoveryTransferDocument,
        recipientRole: DeviceRole,
        activeTrustSession: PeerTrustSession? = nil
    ) async throws -> RecoveryTransferPayload {
        try document.validate()
        return try await verify(
            envelope: document.envelope,
            recipientRole: recipientRole,
            activeTrustSession: activeTrustSession
        )
    }

    func verify(
        envelope: RecoveryTransferEnvelope,
        recipientRole: DeviceRole,
        activeTrustSession: PeerTrustSession? = nil
    ) async throws -> RecoveryTransferPayload {
        guard envelope.recipientRole == recipientRole else {
            throw WalletError.invalidRecoveryTransfer
        }
        guard !envelope.isExpired else {
            throw WalletError.peerTrustExpired
        }
        try await validatePayloadBinding(
            envelope.payload,
            senderRole: envelope.senderRole,
            recipientRole: envelope.recipientRole,
            trustSessionFingerprint: envelope.trustSessionFingerprint,
            activeTrustSession: activeTrustSession
        )

        let unsignedData = try encoder.encode(envelope.unsignedEnvelope())
        let isValid = try await keyManager.verifyPeerSignature(
            signature: envelope.signature,
            payload: unsignedData,
            publicKey: envelope.senderVerifyingKey
        )
        guard isValid else {
            throw WalletError.invalidRecoveryTransfer
        }
        try validateEnvelopeBinding(envelope, activeTrustSession: activeTrustSession)
        return envelope.payload
    }

    private func validatePayloadBinding(
        _ payload: RecoveryTransferPayload,
        senderRole: DeviceRole,
        recipientRole: DeviceRole,
        trustSessionFingerprint: String?,
        activeTrustSession: PeerTrustSession?
    ) async throws {
        switch payload {
        case .authorityBundle(let shares):
            guard senderRole == .authorityPhone,
                  recipientRole == .authorityPhone,
                  shares.count == PeerKind.allCases.count else {
                throw WalletError.invalidRecoveryTransfer
            }
            try await validateRecoveryShares(shares)
        case .peerShare(let share):
            guard isAllowedPeerShareRoute(senderRole: senderRole, recipientRole: recipientRole),
                  let expectedPeerKind = peerKindBoundToTransfer(senderRole: senderRole, recipientRole: recipientRole),
                  share.peerKind == expectedPeerKind else {
                throw WalletError.invalidRecoveryTransfer
            }
            try await validateRecoveryShare(share)
            guard let trustSessionFingerprint, !trustSessionFingerprint.isEmpty else {
                throw WalletError.peerPresenceRequired
            }

            let requiresBoundPresence = senderRole.isRecoveryPeer || recipientRole.isRecoveryPeer
            if requiresBoundPresence {
                _ = try validatedRecoveryTransferSession(
                    activeTrustSession,
                    fingerprint: trustSessionFingerprint
                )
            }
        }
    }

    private func validatedRecoveryTransferSession(
        _ session: PeerTrustSession?,
        fingerprint: String
    ) throws -> PeerTrustSession {
        guard let session, session.isActive else {
            throw WalletError.peerPresenceRequired
        }
        guard session.capabilities.contains(.recoveryTransfer),
              session.transcriptFingerprint == fingerprint else {
            throw WalletError.invalidPeerTrustSession
        }
        return session
    }

    private func validateEnvelopeBinding(
        _ envelope: RecoveryTransferEnvelope,
        activeTrustSession: PeerTrustSession?
    ) throws {
        guard case .peerShare = envelope.payload else {
            return
        }
        guard let fingerprint = envelope.trustSessionFingerprint else {
            throw WalletError.invalidPeerTrustSession
        }
        let session = try validatedRecoveryTransferSession(activeTrustSession, fingerprint: fingerprint)
        guard envelope.senderRole == session.peerRole,
              envelope.senderDeviceID == session.peerDeviceID,
              envelope.senderVerifyingKey == session.peerVerifyingKey else {
            throw WalletError.invalidPeerTrustSession
        }
    }

    private func validateRecoveryShare(_ share: RecoveryShareEnvelope) async throws {
        guard !share.fragment.isEmpty,
              !share.recoveryPackage.sealedState.isEmpty,
              !share.recoveryPackage.stateDigest.isEmpty,
              !share.recoveryPackage.authorityPublicIdentity.isEmpty,
              !share.recoveryPackage.signature.isEmpty,
              !share.rootKeyDigest.isEmpty,
              share.rootKeyDigest == share.recoveryPackage.authorityIdentityDigest else {
            throw WalletError.invalidRecoveryPackage
        }

        let isPackageAuthentic = try await keyManager.verifyAuthoritySignature(
            signature: share.recoveryPackage.signature,
            payload: share.recoveryPackage.signaturePayload(),
            publicKey: share.recoveryPackage.authorityPublicIdentity
        )
        guard isPackageAuthentic else {
            throw WalletError.invalidRecoveryPackage
        }
    }

    private func validateRecoveryShares(_ shares: [RecoveryShareEnvelope]) async throws {
        guard shares.count == PeerKind.allCases.count else {
            throw WalletError.invalidRecoveryPackage
        }
        let peerKinds = Set(shares.map(\.peerKind))
        guard peerKinds == Set(PeerKind.allCases) else {
            throw WalletError.invalidRecoveryPackage
        }
        try await validateRecoveryShare(shares[0])
        let first = shares[0]
        for share in shares.dropFirst() {
            try await validateRecoveryShare(share)
            guard share.recoveryPackage.packageID == first.recoveryPackage.packageID,
                  share.recoveryPackage.sealedState == first.recoveryPackage.sealedState,
                  share.recoveryPackage.stateDigest == first.recoveryPackage.stateDigest,
                  share.recoveryPackage.authorityPublicIdentity == first.recoveryPackage.authorityPublicIdentity,
                  share.recoveryPackage.signature == first.recoveryPackage.signature,
                  share.rootKeyDigest == first.rootKeyDigest else {
                throw WalletError.invalidRecoveryPackage
            }
        }
    }

    private func isAllowedPeerShareRoute(senderRole: DeviceRole, recipientRole: DeviceRole) -> Bool {
        switch (senderRole, recipientRole) {
        case (.authorityPhone, .recoveryPad),
             (.authorityPhone, .recoveryMac),
             (.recoveryPad, .authorityPhone),
             (.recoveryMac, .authorityPhone):
            return true
        default:
            return false
        }
    }

    private func peerKindBoundToTransfer(senderRole: DeviceRole, recipientRole: DeviceRole) -> PeerKind? {
        switch (senderRole, recipientRole) {
        case (_, .recoveryPad), (.recoveryPad, _):
            return .pad
        case (_, .recoveryMac), (.recoveryMac, _):
            return .mac
        default:
            return nil
        }
    }
}
