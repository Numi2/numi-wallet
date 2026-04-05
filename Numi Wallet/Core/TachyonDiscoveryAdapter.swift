import Foundation

protocol TachyonDiscoveryAdapter: Sendable {
    func makeBootstrapQuery(tag: Data, descriptorID: UUID) -> TachyonDiscoveryQuery
    func makeRatchetedQuery(tag: Data, relationshipID: UUID, lookaheadStep: Int) -> TachyonDiscoveryQuery
    func interpret(_ match: TaggedPaymentMatch, tagDigest: Data, knownDescriptorIDs: Set<UUID>) -> TachyonInterpretedMatch
}

struct DefaultTachyonDiscoveryAdapter: TachyonDiscoveryAdapter {
    func makeBootstrapQuery(tag: Data, descriptorID: UUID) -> TachyonDiscoveryQuery {
        TachyonDiscoveryQuery(
            id: UUID(),
            purpose: .bootstrap,
            relationshipID: nil,
            lookaheadStep: nil,
            tag: tag,
            tagDigest: TachyonSupport.digest(tag)
        )
    }

    func makeRatchetedQuery(tag: Data, relationshipID: UUID, lookaheadStep: Int) -> TachyonDiscoveryQuery {
        TachyonDiscoveryQuery(
            id: UUID(),
            purpose: .ratchetLookahead,
            relationshipID: relationshipID,
            lookaheadStep: lookaheadStep,
            tag: tag,
            tagDigest: TachyonSupport.digest(tag)
        )
    }

    func interpret(_ match: TaggedPaymentMatch, tagDigest: Data, knownDescriptorIDs: Set<UUID>) -> TachyonInterpretedMatch {
        let relationshipIsKnown = knownDescriptorIDs.contains(match.recipientDescriptorID)
        return TachyonInterpretedMatch(
            relationshipID: nil,
            advancesExistingRelationship: relationshipIsKnown,
            lookaheadStep: relationshipIsKnown ? 1 : nil,
            tagDigest: tagDigest,
            ciphertextDigest: TachyonSupport.digest(match.noteCiphertext),
            introductionKeyDigest: match.senderIntroductionEncapsulatedKey.map { TachyonSupport.digest($0) },
            receivedAt: match.receivedAt
        )
    }
}
