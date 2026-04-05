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
                    + descriptor.taggingPublicKey
                    + Data(descriptor.id.uuidString.utf8)
            )
        )
    }

    func establishRelationship(
        alias: String?,
        peerDescriptor: PrivateReceiveDescriptor
    ) throws -> (snapshot: TagRelationshipSnapshot, secrets: RatchetSecretMaterial, introductionEncapsulatedKey: Data) {
        guard !peerDescriptor.taggingPublicKey.isEmpty else {
            throw WalletError.descriptorUpgradeRequired
        }

        let peerKey = try XWingMLKEM768X25519.PublicKey(rawRepresentation: peerDescriptor.taggingPublicKey)
        let introduction = try peerKey.encapsulate()
        let rootKey = deriveRootKey(
            from: introduction.sharedSecret,
            offlineToken: peerDescriptor.offlineToken
        )
        let rootData = rootKey.withUnsafeBytes { Data($0) }
        let outgoing = Data(SHA256.hash(data: rootData + Data("outgoing".utf8)))
        let incoming = Data(SHA256.hash(data: rootData + Data("incoming".utf8)))

        return (
            snapshot: TagRelationshipSnapshot(
                id: UUID(),
                alias: alias,
                peerDescriptorID: peerDescriptor.id,
                peerTaggingPublicKey: peerDescriptor.taggingPublicKey,
                introductionEncapsulatedKey: introduction.encapsulated,
                direction: .outbound,
                state: .bootstrapPending,
                nextOutgoingCounter: 0,
                nextIncomingCounter: 0,
                lookaheadWindowSize: 4,
                lastIssuedIncomingLookaheadCounter: 4,
                lastAcceptedIncomingTagDigest: nil,
                acceptedIncomingTagDigests: [],
                acceptedCiphertextDigests: [],
                introductionProvenance: .outboundBootstrap,
                rotationTargetDescriptorID: nil,
                establishedAt: Date(),
                lastActivityAt: nil
            ),
            secrets: RatchetSecretMaterial(outgoingChainKey: outgoing, incomingChainKey: incoming),
            introductionEncapsulatedKey: introduction.encapsulated
        )
    }

    func deriveRecipientRelationship(
        alias: String?,
        descriptor: PrivateReceiveDescriptor,
        descriptorSecrets: DescriptorPrivateMaterial,
        introductionEncapsulatedKey: Data
    ) throws -> (snapshot: TagRelationshipSnapshot, secrets: RatchetSecretMaterial) {
        guard !descriptorSecrets.taggingKey.isEmpty else {
            throw WalletError.descriptorUpgradeRequired
        }

        let localKey = try XWingMLKEM768X25519.PrivateKey(integrityCheckedRepresentation: descriptorSecrets.taggingKey)
        let sharedSecret = try localKey.decapsulate(introductionEncapsulatedKey)
        let rootKey = deriveRootKey(from: sharedSecret, offlineToken: descriptor.offlineToken)
        let rootData = rootKey.withUnsafeBytes { Data($0) }
        let outgoing = Data(SHA256.hash(data: rootData + Data("incoming".utf8)))
        let incoming = Data(SHA256.hash(data: rootData + Data("outgoing".utf8)))

        return (
            snapshot: TagRelationshipSnapshot(
                id: UUID(),
                alias: alias,
                peerDescriptorID: descriptor.id,
                peerTaggingPublicKey: Data(),
                introductionEncapsulatedKey: introductionEncapsulatedKey,
                direction: .inbound,
                state: .introductionReceived,
                nextOutgoingCounter: 0,
                nextIncomingCounter: 0,
                lookaheadWindowSize: 4,
                lastIssuedIncomingLookaheadCounter: 4,
                lastAcceptedIncomingTagDigest: nil,
                acceptedIncomingTagDigests: [],
                acceptedCiphertextDigests: [],
                introductionProvenance: .inboundBootstrap,
                rotationTargetDescriptorID: nil,
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

    private func deriveRootKey(from sharedSecret: SymmetricKey, offlineToken: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: sharedSecret,
            salt: offlineToken,
            info: Data("numi.tag.ratchet.root".utf8),
            outputByteCount: 32
        )
    }
}
