import Foundation

protocol TachyonProofAdapter: Sendable {
    func makeWalletStateCheckJob(profile: WalletProfile, label: String, lane: TachyonProofLane) throws -> TachyonProofJob
    func makeSendProofJob(
        capsule: TachyonSendCapsule,
        profile: WalletProfile,
        witnessRequirements: [TachyonWitnessRequirement],
        lane: TachyonProofLane
    ) throws -> TachyonProofJob
    func verify(_ artifact: TachyonProofArtifact, for job: TachyonProofJob) throws -> TachyonProofArtifact
    func localArtifact(from artifact: TachyonProofArtifact) -> LocalProofArtifact
}

struct RaguTachyonProofAdapter: TachyonProofAdapter {
    var now: @Sendable () -> Date = Date.init
    var jobExpiry: TimeInterval = 20 * 60

    func makeWalletStateCheckJob(
        profile: WalletProfile,
        label: String = "Wallet State Check",
        lane: TachyonProofLane = .foreground
    ) throws -> TachyonProofJob {
        let createdAt = now()
        let bundle = TachyonBundleDraft.walletStateCheck(network: profile.shielded.network, createdAt: createdAt)
        let walletStateDigest = try TachyonSupport.digest(
            encodable: WalletStateDigestMaterial(
                profileVersion: profile.version,
                dayDescriptorID: profile.dayWallet?.activeDescriptor?.id,
                vaultDescriptorID: profile.publicVaultDescriptor?.id,
                trackedNoteCount: profile.shielded.notes.count,
                trackedRelationshipCount: profile.shielded.relationships.count,
                blockHeight: profile.shielded.pirSync.lastKnownBlockHeight
            )
        )
        let transactionDraftDigest = try TachyonSupport.digest(encodable: bundle)
        let witnessDigest = try TachyonSupport.digest(
            encodable: WalletStateWitnessMaterial(
                dayWallet: profile.dayWallet,
                publicRootIdentity: profile.rootPublicIdentity ?? Data(),
                pirSync: profile.shielded.pirSync
            )
        )
        let transcriptDigest = makeTranscriptDigest(
            walletStateDigest: walletStateDigest,
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: nil,
            lane: lane,
            label: label
        )

        return makeJob(
            label: label,
            lane: lane,
            compressionMode: .uncompressed,
            compressionBoundary: .recursiveWork,
            walletStateDigest: walletStateDigest,
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: nil,
            transcriptDigest: transcriptDigest,
            witnessRequirements: [],
            rounds: 512,
            createdAt: createdAt,
            bundle: bundle
        )
    }

    func makeSendProofJob(
        capsule: TachyonSendCapsule,
        profile: WalletProfile,
        witnessRequirements: [TachyonWitnessRequirement],
        lane: TachyonProofLane = .foreground
    ) throws -> TachyonProofJob {
        let createdAt = now()
        let walletStateDigest = try TachyonSupport.digest(
            encodable: WalletStateDigestMaterial(
                profileVersion: profile.version,
                dayDescriptorID: profile.dayWallet?.activeDescriptor?.id,
                vaultDescriptorID: profile.publicVaultDescriptor?.id,
                trackedNoteCount: profile.shielded.notes.count,
                trackedRelationshipCount: profile.shielded.relationships.count,
                blockHeight: profile.shielded.pirSync.lastKnownBlockHeight
            )
        )
        let transactionDraftDigest = try TachyonSupport.digest(encodable: capsule.bundle)
        let witnessDigest = try TachyonSupport.digest(
            encodable: SendWitnessMaterial(
                sourceNoteID: capsule.source.noteID,
                merklePath: capsule.source.merklePath,
                outgoingTagDigest: TachyonSupport.digest(capsule.outgoingTag),
                recipientCiphertextDigest: TachyonSupport.digest(capsule.recipientCiphertext)
            )
        )
        let transcriptDigest = makeTranscriptDigest(
            walletStateDigest: walletStateDigest,
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: capsule.quoteBindingDigest,
            lane: lane,
            label: "Tachyon Send Proof"
        )

        return makeJob(
            label: "Tachyon Send Proof",
            lane: lane,
            compressionMode: .compressed,
            compressionBoundary: .relayPackaging,
            walletStateDigest: walletStateDigest,
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: capsule.quoteBindingDigest,
            transcriptDigest: transcriptDigest,
            witnessRequirements: witnessRequirements,
            rounds: 2_048,
            createdAt: createdAt,
            bundle: capsule.bundle
        )
    }

    func verify(_ artifact: TachyonProofArtifact, for job: TachyonProofJob) throws -> TachyonProofArtifact {
        guard artifact.jobID == job.id else {
            throw WalletError.invalidProofArtifact("Proof job identifier mismatch.")
        }
        guard artifact.requestedJobDigest == job.jobDigest else {
            throw WalletError.invalidProofArtifact("Proof artifact does not bind to the requested job digest.")
        }
        guard artifact.walletStateDigest == job.walletStateDigest else {
            throw WalletError.invalidProofArtifact("Wallet state digest mismatch.")
        }
        guard artifact.transactionDraftDigest == job.transactionDraftDigest else {
            throw WalletError.invalidProofArtifact("Transaction draft digest mismatch.")
        }
        guard artifact.witnessDigest == job.witnessDigest else {
            throw WalletError.invalidProofArtifact("Witness digest mismatch.")
        }
        guard artifact.quoteBindingDigest == job.quoteBindingDigest else {
            throw WalletError.invalidProofArtifact("Quote-binding digest mismatch.")
        }
        guard artifact.transcriptDigest == job.transcriptDigest else {
            throw WalletError.invalidProofArtifact("Transcript digest mismatch.")
        }
        guard artifact.proofDigest == TachyonSupport.digest(artifact.proofData) else {
            throw WalletError.invalidProofArtifact("Proof digest does not match proof bytes.")
        }
        let expectedArtifactDigest = TachyonSupport.artifactDigest(
            jobDigest: job.jobDigest,
            proofDigest: artifact.proofDigest,
            transcriptDigest: artifact.transcriptDigest,
            backend: artifact.backend,
            compressionMode: artifact.compressionMode
        )
        guard artifact.artifactDigest == expectedArtifactDigest else {
            throw WalletError.invalidProofArtifact("Proof artifact digest mismatch.")
        }
        var verified = artifact.verifiedLocally()
        verified.progress.append(
            TachyonProofProgress(
                phase: .verified,
                fractionCompleted: 1.0,
                updatedAt: now(),
                detail: "Verified against the local Tachyon draft before spend authorization."
            )
        )
        return verified
    }

    func localArtifact(from artifact: TachyonProofArtifact) -> LocalProofArtifact {
        let venue = "\(artifact.backend.rawValue) | \(artifact.compressionMode.rawValue)"
        return LocalProofArtifact(
            jobID: artifact.jobID,
            venue: venue,
            duration: artifact.completedAt.timeIntervalSince(artifact.progress.first?.updatedAt ?? artifact.completedAt),
            digest: artifact.artifactDigest,
            completedAt: artifact.completedAt
        )
    }

    func makeCompatibilityJob(from localJob: LocalProofJob) throws -> TachyonProofJob {
        let createdAt = now()
        let bundle = TachyonBundleDraft.walletStateCheck(network: .local, createdAt: createdAt)
        let transactionDraftDigest = try TachyonSupport.digest(encodable: bundle)
        let witnessDigest = TachyonSupport.digest(localJob.witness)
        let transcriptDigest = makeTranscriptDigest(
            walletStateDigest: Data(),
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: nil,
            lane: .foreground,
            label: localJob.label
        )

        return makeJob(
            label: localJob.label,
            lane: .foreground,
            compressionMode: .uncompressed,
            compressionBoundary: .recursiveWork,
            walletStateDigest: Data(),
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: nil,
            transcriptDigest: transcriptDigest,
            witnessRequirements: [],
            rounds: localJob.rounds,
            createdAt: createdAt,
            bundle: bundle
        )
    }

    private func makeJob(
        label: String,
        lane: TachyonProofLane,
        compressionMode: TachyonProofCompressionMode,
        compressionBoundary: TachyonCompressionBoundary,
        walletStateDigest: Data,
        transactionDraftDigest: Data,
        witnessDigest: Data,
        quoteBindingDigest: Data?,
        transcriptDigest: Data,
        witnessRequirements: [TachyonWitnessRequirement],
        rounds: Int,
        createdAt: Date,
        bundle: TachyonBundleDraft
    ) -> TachyonProofJob {
        let jobDigest = TachyonSupport.digest(
            walletStateDigest,
            transactionDraftDigest,
            witnessDigest,
            quoteBindingDigest ?? Data(),
            transcriptDigest,
            Data(lane.rawValue.utf8),
            Data(compressionMode.rawValue.utf8),
            Data(compressionBoundary.rawValue.utf8),
            Data(label.utf8)
        )

        return TachyonProofJob(
            id: UUID(),
            label: label,
            lane: lane,
            compressionMode: compressionMode,
            compressionBoundary: compressionBoundary,
            walletStateDigest: walletStateDigest,
            transactionDraftDigest: transactionDraftDigest,
            witnessDigest: witnessDigest,
            quoteBindingDigest: quoteBindingDigest,
            transcriptDigest: transcriptDigest,
            jobDigest: jobDigest,
            witnessRequirements: witnessRequirements,
            rounds: rounds,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(jobExpiry),
            bundle: bundle
        )
    }

    private func makeTranscriptDigest(
        walletStateDigest: Data,
        transactionDraftDigest: Data,
        witnessDigest: Data,
        quoteBindingDigest: Data?,
        lane: TachyonProofLane,
        label: String
    ) -> Data {
        TachyonSupport.digest(
            walletStateDigest,
            transactionDraftDigest,
            witnessDigest,
            quoteBindingDigest ?? Data(),
            Data(lane.rawValue.utf8),
            Data(label.utf8)
        )
    }
}

private struct WalletStateDigestMaterial: Codable {
    var profileVersion: Int
    var dayDescriptorID: UUID?
    var vaultDescriptorID: UUID?
    var trackedNoteCount: Int
    var trackedRelationshipCount: Int
    var blockHeight: UInt64
}

private struct WalletStateWitnessMaterial: Codable {
    var dayWallet: DayWalletSnapshot?
    var publicRootIdentity: Data
    var pirSync: PIRSyncSnapshot
}

private struct SendWitnessMaterial: Codable {
    var sourceNoteID: UUID
    var merklePath: ShieldedMerklePath
    var outgoingTagDigest: Data
    var recipientCiphertextDigest: Data
}
