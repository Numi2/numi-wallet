import CryptoKit
import Foundation

private struct RelayCiphertext: Codable {
    var encapsulatedKey: Data
    var ciphertext: Data
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
        let recipientKey = try XWingMLKEM768X25519.PublicKey(rawRepresentation: descriptor.deliveryPublicKey)
        var sender = try HPKE.Sender(
            recipientKey: recipientKey,
            ciphersuite: .XWingMLKEM768X25519_SHA256_AES_GCM_256,
            info: relayInfo(for: descriptor)
        )
        let sealed = try sender.seal(plaintext, authenticating: relayAssociatedData(for: descriptor))
        let ciphertext = RelayCiphertext(
            encapsulatedKey: sender.encapsulatedKey,
            ciphertext: sealed
        )
        return try JSONEncoder().encode(ciphertext)
    }

    func decryptRelayPayload(
        _ ciphertext: Data,
        descriptorPrivateKey: Data,
        descriptor: PrivateReceiveDescriptor
    ) throws -> Data {
        let privateKey = try XWingMLKEM768X25519.PrivateKey(integrityCheckedRepresentation: descriptorPrivateKey)
        let relayCiphertext = try JSONDecoder().decode(RelayCiphertext.self, from: ciphertext)
        var recipient = try HPKE.Recipient(
            privateKey: privateKey,
            ciphersuite: .XWingMLKEM768X25519_SHA256_AES_GCM_256,
            info: relayInfo(for: descriptor),
            encapsulatedKey: relayCiphertext.encapsulatedKey
        )
        return try recipient.open(
            relayCiphertext.ciphertext,
            authenticating: relayAssociatedData(for: descriptor)
        )
    }

    private func releaseSlot(for date: Date) -> Date {
        let epoch = date.timeIntervalSince1970
        let bucket = floor(epoch / batchWindow) * batchWindow
        return Date(timeIntervalSince1970: bucket + batchWindow)
    }

    private func relayInfo(for descriptor: PrivateReceiveDescriptor) -> Data {
        Data("numi.relay.hpke.xwing.\(descriptor.id.uuidString).\(descriptor.rotation).\(descriptor.tier.rawValue)".utf8)
    }

    private func relayAssociatedData(for descriptor: PrivateReceiveDescriptor) -> Data {
        var payload = Data()
        payload.append(descriptor.deliveryPublicKey)
        payload.append(descriptor.taggingPublicKey)
        payload.append(descriptor.offlineToken)
        payload.append(descriptor.issuerIdentity)
        payload.append(contentsOf: descriptor.id.uuidString.utf8)
        payload.append(contentsOf: descriptor.tier.rawValue.utf8)
        payload.append(contentsOf: String(descriptor.rotation).utf8)
        return Data(SHA256.hash(data: payload))
    }
}
