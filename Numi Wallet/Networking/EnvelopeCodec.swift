import CryptoKit
import Foundation

private struct RelayCiphertext: Codable {
    var ephemeralPublicKey: Data
    var combinedSealedBox: Data
}

struct EnvelopeCodec: Sendable {
    let fixedSize: Int
    let batchWindow: TimeInterval

    init(configuration: RemoteServiceConfiguration) {
        self.fixedSize = configuration.fixedEnvelopeSize
        self.batchWindow = configuration.batchWindow
    }

    func blindedAliasToken(alias: String) -> Data {
        let normalized = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload = Data("numi.alias.\(normalized)".utf8)
        return Data(SHA256.hash(data: payload))
    }

    func makeEnvelope(
        kind: EnvelopeKind,
        payload: Data,
        attestation: AppAttestArtifact?,
        budget: Int? = nil
    ) throws -> PaddedEnvelope {
        let effectiveBudget = budget ?? fixedSize
        let encodedLength = payload.count + (attestation.map { $0.assertion.count + $0.clientDataHash.count + $0.keyID.utf8.count } ?? 0)
        guard encodedLength <= effectiveBudget else {
            throw WalletError.remoteServiceUnavailable("Envelope payload exceeds fixed transport budget")
        }

        let paddingCount = max(0, effectiveBudget - encodedLength)
        return PaddedEnvelope(
            envelopeID: UUID(),
            kind: kind,
            createdAt: Date(),
            releaseSlot: releaseSlot(for: Date()),
            payload: payload,
            padding: Data((0..<paddingCount).map { _ in UInt8.random(in: .min ... .max) }),
            attestation: attestation
        )
    }

    func encryptRelayPayload(_ plaintext: Data, to descriptor: PrivateReceiveDescriptor) throws -> Data {
        let recipientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: descriptor.deliveryCurve25519PublicKey)
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let secret = try ephemeral.sharedSecretFromKeyAgreement(with: recipientKey)
        let symmetricKey = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: descriptor.offlineToken,
            sharedInfo: Data("numi.relay.e2ee".utf8),
            outputByteCount: 32
        )
        let sealed = try ChaChaPoly.seal(plaintext, using: symmetricKey)
        let ciphertext = RelayCiphertext(
            ephemeralPublicKey: ephemeral.publicKey.rawRepresentation,
            combinedSealedBox: sealed.combined
        )
        return try JSONEncoder().encode(ciphertext)
    }

    func decryptRelayPayload(
        _ ciphertext: Data,
        descriptorPrivateKey: Data,
        descriptor: PrivateReceiveDescriptor
    ) throws -> Data {
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: descriptorPrivateKey)
        let relayCiphertext = try JSONDecoder().decode(RelayCiphertext.self, from: ciphertext)
        let ephemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: relayCiphertext.ephemeralPublicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralKey)
        let symmetricKey = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: descriptor.offlineToken,
            sharedInfo: Data("numi.relay.e2ee".utf8),
            outputByteCount: 32
        )
        let sealedBox = try ChaChaPoly.SealedBox(combined: relayCiphertext.combinedSealedBox)
        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }

    private func releaseSlot(for date: Date) -> Date {
        let epoch = date.timeIntervalSince1970
        let bucket = floor(epoch / batchWindow) * batchWindow
        return Date(timeIntervalSince1970: bucket + batchWindow)
    }
}
