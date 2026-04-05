import Foundation

protocol TachyonTransactionAdapter: Sendable {
    func makeSendCapsule(
        draft: SpendDraft,
        source: ShieldedSpendSource,
        descriptor: PrivateReceiveDescriptor,
        relationshipID: UUID?,
        outgoingTag: Data,
        isIntroductionPayment: Bool,
        recipientCiphertext: Data,
        feeAuthorization: DynamicFeeAuthorizationBundle,
        network: WalletNetwork
    ) throws -> TachyonSendCapsule
    func makeSubmissionEnvelope(
        capsule: TachyonSendCapsule,
        proofArtifact: TachyonProofArtifact?,
        relayPayload: ShieldedSpendSubmission
    ) throws -> TachyonSubmissionEnvelope
}

struct DefaultTachyonTransactionAdapter: TachyonTransactionAdapter {
    func makeSendCapsule(
        draft: SpendDraft,
        source: ShieldedSpendSource,
        descriptor: PrivateReceiveDescriptor,
        relationshipID: UUID?,
        outgoingTag: Data,
        isIntroductionPayment: Bool,
        recipientCiphertext: Data,
        feeAuthorization: DynamicFeeAuthorizationBundle,
        network: WalletNetwork
    ) throws -> TachyonSendCapsule {
        let action = TachyonActionDraft(
            id: UUID(),
            sourceNoteID: source.noteID,
            destinationDescriptorID: descriptor.id,
            amount: draft.amount,
            outgoingTag: outgoingTag,
            valueCommitmentDigest: try TachyonSupport.digest(encodable: draft.amount),
            randomizedKeyDigest: TachyonSupport.digest(descriptor.taggingPublicKey, descriptor.signature),
            spendAuthorizationDigest: nil,
            recipientCiphertextDigest: TachyonSupport.digest(recipientCiphertext)
        )
        let stamp = TachyonStampDraft(
            id: UUID(),
            anchorRoot: source.merklePath.root,
            nullifiers: [source.nullifier],
            noteCommitments: [source.noteCommitment],
            proofBoundary: .relayPackaging
        )
        let bundle = TachyonBundleDraft(
            id: UUID(),
            spendDraftID: draft.id,
            tier: draft.tier,
            network: network,
            recipientDescriptorID: descriptor.id,
            amount: draft.amount,
            maximumFee: draft.maximumFee,
            quoteID: feeAuthorization.quote.quoteID,
            actions: [action],
            stamp: stamp,
            createdAt: Date()
        )
        let quoteBindingDigest = try TachyonSupport.digest(
            encodable: QuoteBindingDigestMaterial(
                quoteID: feeAuthorization.quote.quoteID,
                marketRatePerWeight: feeAuthorization.quote.marketRatePerWeight,
                settlementDigest: feeAuthorization.settlement.settlementDigest,
                maximumFee: feeAuthorization.commitmentProof.maximumFee.minorUnits
            )
        )

        return TachyonSendCapsule(
            id: UUID(),
            draft: draft,
            network: network,
            source: source,
            destinationDescriptorID: descriptor.id,
            relationshipID: relationshipID,
            outgoingTag: outgoingTag,
            isIntroductionPayment: isIntroductionPayment,
            recipientCiphertext: recipientCiphertext,
            feeAuthorization: feeAuthorization,
            bundle: bundle,
            quoteBindingDigest: quoteBindingDigest,
            createdAt: Date()
        )
    }

    func makeSubmissionEnvelope(
        capsule: TachyonSendCapsule,
        proofArtifact: TachyonProofArtifact?,
        relayPayload: ShieldedSpendSubmission
    ) throws -> TachyonSubmissionEnvelope {
        TachyonSubmissionEnvelope(
            capsuleID: capsule.id,
            bundleDigest: try TachyonSupport.digest(encodable: capsule.bundle),
            proofDigest: proofArtifact?.proofDigest,
            proofCompressionMode: proofArtifact?.compressionMode,
            relayPayloadDigest: try TachyonSupport.digest(encodable: relayPayload),
            createdAt: Date()
        )
    }
}

private struct QuoteBindingDigestMaterial: Codable {
    var quoteID: UUID
    var marketRatePerWeight: UInt64
    var settlementDigest: Data
    var maximumFee: Int64
}
