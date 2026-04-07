import Foundation

enum TachyonProofLane: String, Codable, Sendable {
    case foreground
    case continuedProcessing
    case resumed
}

enum TachyonProofExecutionGrant: String, Codable, Sendable {
    case foregroundUnrestricted
    case continuedProcessingCPU
    case continuedProcessingGPU

    var requiresContinuedProcessingTask: Bool {
        switch self {
        case .foregroundUnrestricted:
            return false
        case .continuedProcessingCPU, .continuedProcessingGPU:
            return true
        }
    }

    var permitsGPU: Bool {
        self == .continuedProcessingGPU
    }
}

enum TachyonProofBackendKind: String, Codable, Sendable {
    case metalFallback
    case cpuFallback
}

enum TachyonProofCompressionMode: String, Codable, Sendable {
    case uncompressed
    case compressed
}

enum TachyonCompressionBoundary: String, Codable, Sendable {
    case recursiveWork
    case relayPackaging
    case archivalStorage
}

enum TachyonProofProgressPhase: String, Codable, Sendable {
    case prepared
    case witnessBound
    case accumulated
    case compressed
    case verified
}

enum TachyonProofVerificationStatus: String, Codable, Sendable {
    case unverified
    case verifiedLocally
}

enum TachyonProofCheckpointState: String, Codable, Sendable {
    case queued
    case running
    case proofReady
    case expired
    case failed
}

enum TachyonDiscoveryQueryPurpose: String, Codable, Sendable {
    case bootstrap
    case ratchetLookahead
}

struct TachyonWitnessRequirement: Codable, Hashable, Sendable {
    var noteID: UUID
    var noteCommitment: Data
    var nullifier: Data
    var anchorRoot: Data?
    var merklePathDigest: Data?
    var lastRefreshAt: Date?
    var requiresRefresh: Bool
}

struct TachyonDecodedNote: Codable, Hashable, Sendable {
    var noteCommitment: Data
    var nullifier: Data
    var amount: MoneyAmount
    var memo: String
    var descriptorID: UUID
    var relationshipID: UUID?
    var latestTag: Data?
    var receivedAt: Date
}

struct TachyonDiscoveryQuery: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var purpose: TachyonDiscoveryQueryPurpose
    var relationshipID: UUID?
    var lookaheadStep: Int?
    var tag: Data
    var tagDigest: Data
}

struct TachyonInterpretedMatch: Codable, Hashable, Sendable {
    var relationshipID: UUID?
    var advancesExistingRelationship: Bool
    var lookaheadStep: Int?
    var tagDigest: Data
    var ciphertextDigest: Data
    var introductionKeyDigest: Data?
    var receivedAt: Date
}

struct TachyonActionDraft: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var sourceNoteID: UUID
    var destinationDescriptorID: UUID
    var amount: MoneyAmount
    var outgoingTag: Data
    var valueCommitmentDigest: Data
    var randomizedKeyDigest: Data
    var spendAuthorizationDigest: Data?
    var recipientCiphertextDigest: Data
}

struct TachyonStampDraft: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var anchorRoot: Data
    var nullifiers: [Data]
    var noteCommitments: [Data]
    var proofBoundary: TachyonCompressionBoundary
}

struct TachyonBundleDraft: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var spendDraftID: UUID
    var tier: WalletTier
    var network: WalletNetwork
    var recipientDescriptorID: UUID
    var amount: MoneyAmount
    var maximumFee: MoneyAmount
    var quoteID: UUID?
    var actions: [TachyonActionDraft]
    var stamp: TachyonStampDraft
    var createdAt: Date
}

struct TachyonProofProgress: Codable, Hashable, Sendable {
    var phase: TachyonProofProgressPhase
    var fractionCompleted: Double
    var updatedAt: Date
    var detail: String?
}

struct TachyonProofMetrics: Codable, Sendable {
    var rounds: Int
    var witnessBytes: Int
    var proofBytes: Int
    var compressedProofBytes: Int?
    var usedGPU: Bool
}

struct TachyonProofJob: Codable, Sendable, Identifiable {
    var id: UUID
    var label: String
    var lane: TachyonProofLane
    var executionGrant: TachyonProofExecutionGrant
    var compressionMode: TachyonProofCompressionMode
    var compressionBoundary: TachyonCompressionBoundary
    var walletStateDigest: Data
    var transactionDraftDigest: Data
    var witnessDigest: Data
    var quoteBindingDigest: Data?
    var transcriptDigest: Data
    var jobDigest: Data
    var witnessRequirements: [TachyonWitnessRequirement]
    var rounds: Int
    var createdAt: Date
    var expiresAt: Date
    var bundle: TachyonBundleDraft
}

struct TachyonProofArtifact: Codable, Sendable {
    var jobID: UUID
    var requestedJobDigest: Data
    var backend: TachyonProofBackendKind
    var lane: TachyonProofLane
    var executionGrant: TachyonProofExecutionGrant
    var compressionMode: TachyonProofCompressionMode
    var compressionBoundary: TachyonCompressionBoundary
    var walletStateDigest: Data
    var transactionDraftDigest: Data
    var witnessDigest: Data
    var quoteBindingDigest: Data?
    var transcriptDigest: Data
    var proofDigest: Data
    var artifactDigest: Data
    var proofData: Data
    var progress: [TachyonProofProgress]
    var metrics: TachyonProofMetrics
    var verificationStatus: TachyonProofVerificationStatus
    var completedAt: Date
}

struct TachyonProofCheckpoint: Codable, Sendable, Identifiable {
    var id: UUID
    var taskIdentifier: String?
    var state: TachyonProofCheckpointState
    var capsule: TachyonSendCapsule
    var job: TachyonProofJob
    var progress: [TachyonProofProgress]
    var artifact: TachyonProofArtifact?
    var lastError: String?
    var createdAt: Date
    var updatedAt: Date
}

struct TachyonSendCapsule: Codable, Sendable, Identifiable {
    var id: UUID
    var draft: SpendDraft
    var network: WalletNetwork
    var source: ShieldedSpendSource
    var destinationDescriptorID: UUID
    var relationshipID: UUID?
    var outgoingTag: Data
    var isIntroductionPayment: Bool
    var recipientCiphertext: Data
    var feeAuthorization: DynamicFeeAuthorizationBundle
    var bundle: TachyonBundleDraft
    var quoteBindingDigest: Data
    var createdAt: Date
}

struct TachyonSubmissionEnvelope: Codable, Sendable {
    var capsuleID: UUID
    var bundleDigest: Data
    var proofDigest: Data?
    var proofCompressionMode: TachyonProofCompressionMode?
    var relayPayloadDigest: Data
    var createdAt: Date
}

extension TachyonBundleDraft {
    static func walletStateCheck(network: WalletNetwork, createdAt: Date) -> TachyonBundleDraft {
        let stamp = TachyonStampDraft(
            id: UUID(),
            anchorRoot: Data(),
            nullifiers: [],
            noteCommitments: [],
            proofBoundary: .recursiveWork
        )
        return TachyonBundleDraft(
            id: UUID(),
            spendDraftID: UUID(),
            tier: .day,
            network: network,
            recipientDescriptorID: UUID(),
            amount: .zero,
            maximumFee: .zero,
            quoteID: nil,
            actions: [],
            stamp: stamp,
            createdAt: createdAt
        )
    }
}

extension TachyonProofArtifact {
    func verifiedLocally() -> TachyonProofArtifact {
        var copy = self
        copy.verificationStatus = .verifiedLocally
        return copy
    }
}
