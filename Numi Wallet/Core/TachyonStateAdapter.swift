import Foundation

protocol TachyonStateAdapter: Sendable {
    func makeDecodedNote(
        from payload: ShieldedRecipientPayload,
        match: TaggedPaymentMatch,
        descriptor: PrivateReceiveDescriptor,
        relationshipID: UUID?
    ) throws -> TachyonDecodedNote
    func nullifierQueryInputs(for notes: [ShieldedNoteWitness]) -> [Data]
    func witnessRefreshRequirements(for notes: [ShieldedNoteWitness]) -> [TachyonWitnessRequirement]
}

struct DefaultTachyonStateAdapter: TachyonStateAdapter {
    func makeDecodedNote(
        from payload: ShieldedRecipientPayload,
        match: TaggedPaymentMatch,
        descriptor: PrivateReceiveDescriptor,
        relationshipID: UUID?
    ) throws -> TachyonDecodedNote {
        guard match.recipientDescriptorID == descriptor.id else {
            throw WalletError.invalidShieldedPayload("Matched descriptor does not align with the active receive intent.")
        }
        guard payload.recipientDescriptorID == descriptor.id else {
            throw WalletError.invalidShieldedPayload("Decrypted payload targets a different receive descriptor.")
        }
        guard payload.noteCommitment.isEmpty == false else {
            throw WalletError.invalidShieldedPayload("Missing note commitment.")
        }
        guard payload.nullifier.isEmpty == false else {
            throw WalletError.invalidShieldedPayload("Missing nullifier.")
        }
        guard payload.amount.minorUnits > 0 else {
            throw WalletError.invalidShieldedPayload("Received amount must be positive.")
        }
        guard payload.amount.currencyCode == "NUMI" else {
            throw WalletError.invalidShieldedPayload("Received amount uses an unsupported asset code.")
        }
        guard payload.createdAt.timeIntervalSince1970 > 0 else {
            throw WalletError.invalidShieldedPayload("Missing creation timestamp.")
        }
        guard payload.senderIntroductionEncapsulatedKey == match.senderIntroductionEncapsulatedKey else {
            throw WalletError.invalidShieldedPayload("Introduction material does not match the discovery envelope.")
        }

        return TachyonDecodedNote(
            noteCommitment: payload.noteCommitment,
            nullifier: payload.nullifier,
            amount: payload.amount,
            memo: payload.memo,
            descriptorID: descriptor.id,
            relationshipID: relationshipID,
            latestTag: match.tag,
            receivedAt: payload.createdAt
        )
    }

    func nullifierQueryInputs(for notes: [ShieldedNoteWitness]) -> [Data] {
        notes
            .filter { $0.spendState != .spent }
            .map(\.nullifier)
    }

    func witnessRefreshRequirements(for notes: [ShieldedNoteWitness]) -> [TachyonWitnessRequirement] {
        notes.map { note in
            let merklePathDigest = note.merklePath.flatMap { path in
                let siblingDigest = TachyonSupport.digest(path.siblings.flatMap { [$0.hash, Data($0.side.rawValue.utf8)] })
                return TachyonSupport.digest(path.root, siblingDigest)
            }

            return TachyonWitnessRequirement(
                noteID: note.id,
                noteCommitment: note.noteCommitment,
                nullifier: note.nullifier,
                anchorRoot: note.merklePath?.root,
                merklePathDigest: merklePathDigest,
                lastRefreshAt: note.lastMerkleUpdateAt ?? note.lastNullifierCheckAt,
                requiresRefresh: note.merklePath == nil || note.lastNullifierCheckAt == nil
            )
        }
    }
}
