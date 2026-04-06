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
        peerPresenceAssertion: PeerPresenceAssertion? = nil,
        ttl: TimeInterval = 10 * 60
    ) async throws -> RecoveryTransferEnvelope {
        let activeTrustSession = trustSession?.isActive == true ? trustSession : nil
        let activePresenceAssertion = peerPresenceAssertion?.isActive == true ? peerPresenceAssertion : nil
        try await validatePayloadBinding(
            payload,
            senderRole: senderRole,
            recipientRole: recipientRole,
            trustSessionFingerprint: activeTrustSession?.transcriptFingerprint,
            activeTrustSession: activeTrustSession,
            activePresenceAssertion: activePresenceAssertion
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
        activeTrustSession: PeerTrustSession? = nil,
        peerPresenceAssertion: PeerPresenceAssertion? = nil
    ) async throws -> RecoveryTransferPayload {
        try document.validate()
        return try await verify(
            envelope: document.envelope,
            recipientRole: recipientRole,
            activeTrustSession: activeTrustSession,
            peerPresenceAssertion: peerPresenceAssertion
        )
    }

    func verify(
        envelope: RecoveryTransferEnvelope,
        recipientRole: DeviceRole,
        activeTrustSession: PeerTrustSession? = nil,
        peerPresenceAssertion: PeerPresenceAssertion? = nil
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
            activeTrustSession: activeTrustSession,
            activePresenceAssertion: peerPresenceAssertion
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
        return envelope.payload
    }

    private func validatePayloadBinding(
        _ payload: RecoveryTransferPayload,
        senderRole: DeviceRole,
        recipientRole: DeviceRole,
        trustSessionFingerprint: String?,
        activeTrustSession: PeerTrustSession?,
        activePresenceAssertion: PeerPresenceAssertion?
    ) async throws {
        switch payload {
        case .authorityBundle(let shares):
            guard senderRole == .authorityPhone,
                  recipientRole == .authorityPhone,
                  !shares.isEmpty else {
                throw WalletError.invalidRecoveryTransfer
            }
        case .peerShare(let share):
            guard isAllowedPeerShareRoute(senderRole: senderRole, recipientRole: recipientRole),
                  let expectedPeerKind = peerKindBoundToTransfer(senderRole: senderRole, recipientRole: recipientRole),
                  share.peerKind == expectedPeerKind else {
                throw WalletError.invalidRecoveryTransfer
            }
            guard !share.fragment.isEmpty,
                  !share.recoveryPackage.sealedState.isEmpty,
                  !share.recoveryPackage.stateDigest.isEmpty,
                  !share.rootKeyDigest.isEmpty else {
                throw WalletError.invalidRecoveryTransfer
            }
            guard let trustSessionFingerprint, !trustSessionFingerprint.isEmpty else {
                throw WalletError.peerPresenceRequired
            }

            let requiresBoundPresence = senderRole.isRecoveryPeer || recipientRole.isRecoveryPeer
            if requiresBoundPresence {
                let peerPresent = try await validatedPeerPresence(
                    session: activeTrustSession,
                    assertion: activePresenceAssertion
                )
                guard peerPresent else {
                    throw WalletError.peerPresenceRequired
                }
            }

            if recipientRole.isRecoveryPeer {
                guard let activeTrustSession else {
                    throw WalletError.peerPresenceRequired
                }
                guard activeTrustSession.isActive,
                      activeTrustSession.transcriptFingerprint == trustSessionFingerprint else {
                    throw WalletError.invalidPeerTrustSession
                }
            }
        }
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

        let payload = try encoder.encode(assertion.unsignedAssertion())
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
