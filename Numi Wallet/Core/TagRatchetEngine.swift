import CryptoKit
import Foundation

struct RatchetedTag {
    var tag: Data
    var updatedChainKey: Data
}

struct TagRatchetEngine: Sendable {
    func bootstrapTag(for descriptor: PrivateReceiveDescriptor) -> Data {
        Data(
            SHA256.hash(
                data: Data("numi.tag.bootstrap".utf8)
                    + descriptor.taggingCurve25519PublicKey
                    + Data(descriptor.id.uuidString.utf8)
            )
        )
    }

    func establishRelationship(
        alias: String?,
        peerDescriptor: PrivateReceiveDescriptor
    ) throws -> (snapshot: TagRelationshipSnapshot, secrets: RatchetSecretMaterial, introductionPublicKey: Data) {
        guard !peerDescriptor.taggingCurve25519PublicKey.isEmpty else {
            throw WalletError.descriptorUpgradeRequired
        }

        let introductionKey = Curve25519.KeyAgreement.PrivateKey()
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerDescriptor.taggingCurve25519PublicKey)
        let sharedSecret = try introductionKey.sharedSecretFromKeyAgreement(with: peerKey)
        let rootKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: peerDescriptor.offlineToken,
            sharedInfo: Data("numi.tag.ratchet.root".utf8),
            outputByteCount: 32
        )
        let rootData = rootKey.withUnsafeBytes { Data($0) }
        let outgoing = Data(SHA256.hash(data: rootData + Data("outgoing".utf8)))
        let incoming = Data(SHA256.hash(data: rootData + Data("incoming".utf8)))

        return (
            snapshot: TagRelationshipSnapshot(
                id: UUID(),
                alias: alias,
                peerDescriptorID: peerDescriptor.id,
                peerTaggingPublicKey: peerDescriptor.taggingCurve25519PublicKey,
                introductionPublicKey: introductionKey.publicKey.rawRepresentation,
                direction: .outbound,
                nextOutgoingCounter: 0,
                nextIncomingCounter: 0,
                establishedAt: Date(),
                lastActivityAt: nil
            ),
            secrets: RatchetSecretMaterial(outgoingChainKey: outgoing, incomingChainKey: incoming),
            introductionPublicKey: introductionKey.publicKey.rawRepresentation
        )
    }

    func deriveRecipientRelationship(
        alias: String?,
        descriptor: PrivateReceiveDescriptor,
        descriptorSecrets: DescriptorPrivateMaterial,
        introductionPublicKey: Data
    ) throws -> (snapshot: TagRelationshipSnapshot, secrets: RatchetSecretMaterial) {
        guard !descriptorSecrets.taggingKey.isEmpty else {
            throw WalletError.descriptorUpgradeRequired
        }

        let localKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: descriptorSecrets.taggingKey)
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: introductionPublicKey)
        let sharedSecret = try localKey.sharedSecretFromKeyAgreement(with: peerKey)
        let rootKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: descriptor.offlineToken,
            sharedInfo: Data("numi.tag.ratchet.root".utf8),
            outputByteCount: 32
        )
        let rootData = rootKey.withUnsafeBytes { Data($0) }
        let outgoing = Data(SHA256.hash(data: rootData + Data("incoming".utf8)))
        let incoming = Data(SHA256.hash(data: rootData + Data("outgoing".utf8)))

        return (
            snapshot: TagRelationshipSnapshot(
                id: UUID(),
                alias: alias,
                peerDescriptorID: descriptor.id,
                peerTaggingPublicKey: introductionPublicKey,
                introductionPublicKey: introductionPublicKey,
                direction: .inbound,
                nextOutgoingCounter: 0,
                nextIncomingCounter: 0,
                establishedAt: Date(),
                lastActivityAt: Date()
            ),
            secrets: RatchetSecretMaterial(outgoingChainKey: outgoing, incomingChainKey: incoming)
        )
    }

    func advanceOutgoingTag(using material: RatchetSecretMaterial) -> RatchetedTag {
        ratchet(chainKey: material.outgoingChainKey)
    }

    func advanceIncomingTag(using material: RatchetSecretMaterial) -> RatchetedTag {
        ratchet(chainKey: material.incomingChainKey)
    }

    func lookaheadTags(using chainKey: Data, count: Int) -> [Data] {
        guard count > 0 else { return [] }

        var tags: [Data] = []
        var cursor = chainKey
        for _ in 0..<count {
            let ratcheted = ratchet(chainKey: cursor)
            tags.append(ratcheted.tag)
            cursor = ratcheted.updatedChainKey
        }
        return tags
    }

    private func ratchet(chainKey: Data) -> RatchetedTag {
        let tag = Data(SHA256.hash(data: chainKey + Data("tag".utf8)))
        let next = Data(SHA256.hash(data: chainKey + Data("next".utf8)))
        return RatchetedTag(tag: tag, updatedChainKey: next)
    }
}
