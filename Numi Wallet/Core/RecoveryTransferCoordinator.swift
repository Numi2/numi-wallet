import Foundation

actor RecoveryTransferCoordinator {
    private let keyManager: SecureEnclaveKeyManager
    private let localDeviceID: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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
        let unsigned = UnsignedRecoveryTransferEnvelope(
            id: UUID(),
            senderRole: senderRole,
            senderDeviceID: localDeviceID,
            senderVerifyingKey: try await keyManager.ensurePeerIdentityPublicKey(),
            recipientRole: recipientRole,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(ttl),
            trustSessionFingerprint: trustSession?.transcriptFingerprint,
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

    func resolvePayload(from text: String, recipientRole: DeviceRole) async throws -> RecoveryTransferPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)

        if let envelope = try? decoder.decode(RecoveryTransferEnvelope.self, from: data) {
            return try await verify(envelope: envelope, recipientRole: recipientRole)
        }

        if let share = try? decoder.decode(RecoveryShareEnvelope.self, from: data) {
            return .peerShare(share)
        }

        if let shares = try? decoder.decode([RecoveryShareEnvelope].self, from: data) {
            return .authorityBundle(shares)
        }

        throw WalletError.invalidRecoveryPackage
    }

    func verify(envelope: RecoveryTransferEnvelope, recipientRole: DeviceRole) async throws -> RecoveryTransferPayload {
        guard envelope.recipientRole == recipientRole else {
            throw WalletError.invalidRecoveryTransfer
        }
        guard !envelope.isExpired else {
            throw WalletError.peerTrustExpired
        }

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
}
