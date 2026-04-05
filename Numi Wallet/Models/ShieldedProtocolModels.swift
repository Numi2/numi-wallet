import Foundation

enum WalletNetwork: String, Codable, CaseIterable, Identifiable, Sendable {
    case mainnet
    case testnet
    case local

    var id: String { rawValue }
}

enum MerkleSide: String, Codable, Sendable {
    case left
    case right
}

enum ShieldedNoteSpendState: String, Codable, Sendable {
    case ready
    case pendingSubmission
    case spent
}

enum TagRelationshipDirection: String, Codable, Sendable {
    case outbound
    case inbound
    case bidirectional
}

enum ShieldedRefreshTrigger: String, Codable, Sendable {
    case launch
    case foregroundResume
    case backgroundMaintenance
    case preSpend
    case manual
}

struct DescriptorPrivateMaterial: Codable, Sendable {
    var deliveryKey: Data
    var taggingKey: Data
}

struct RatchetSecretMaterial: Codable, Sendable {
    var outgoingChainKey: Data
    var incomingChainKey: Data
}

struct MerklePathElement: Codable, Hashable, Sendable {
    var hash: Data
    var side: MerkleSide
}

struct ShieldedMerklePath: Codable, Hashable, Sendable {
    var root: Data
    var leafIndex: UInt64
    var anchorHeight: UInt64
    var siblings: [MerklePathElement]
}

struct ShieldedNoteWitness: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var tier: WalletTier
    var noteCommitment: Data
    var nullifier: Data
    var amount: MoneyAmount
    var memo: String?
    var receivedAt: Date
    var descriptorID: UUID
    var relationshipID: UUID?
    var latestTag: Data?
    var merklePath: ShieldedMerklePath?
    var lastMerkleUpdateAt: Date?
    var lastNullifierCheckAt: Date?
    var spendState: ShieldedNoteSpendState

    var isSpendable: Bool {
        spendState == .ready && merklePath != nil
    }
}

struct TagRelationshipSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var alias: String?
    var peerDescriptorID: UUID
    var peerTaggingPublicKey: Data
    var introductionEncapsulatedKey: Data?
    var direction: TagRelationshipDirection
    var nextOutgoingCounter: UInt64
    var nextIncomingCounter: UInt64
    var establishedAt: Date
    var lastActivityAt: Date?
}

struct PIRBandwidthSnapshot: Codable, Sendable {
    var merklePathBytes: Int
    var nullifierBytes: Int
    var tagBytes: Int

    var totalBytes: Int {
        merklePathBytes + nullifierBytes + tagBytes
    }

    static let zero = PIRBandwidthSnapshot(merklePathBytes: 0, nullifierBytes: 0, tagBytes: 0)
}

struct PIRSyncSnapshot: Codable, Sendable {
    var lastRefreshAt: Date?
    var lastKnownBlockHeight: UInt64
    var lastBandwidth: PIRBandwidthSnapshot
    var readyForImmediateSpend: Bool
    var lastError: String?

    static let empty = PIRSyncSnapshot(
        lastRefreshAt: nil,
        lastKnownBlockHeight: 0,
        lastBandwidth: .zero,
        readyForImmediateSpend: false,
        lastError: nil
    )
}

struct FeeQuote: Codable, Hashable, Sendable {
    var quoteID: UUID
    var marketRatePerWeight: UInt64
    var recommendedFee: MoneyAmount
    var expiresAt: Date
    var fetchedAt: Date
}

struct FeeCommitmentProof: Codable, Sendable {
    var algorithm: String
    var commitment: Data
    var witnessDigest: Data
    var maximumFee: MoneyAmount
    var generatedAt: Date
}

struct AuthorizedFeeHotkey: Codable, Sendable {
    var algorithm: String
    var publicKey: Data
    var authorizationSignature: Data
    var expiresAt: Date
}

struct FeeSettlementAuthorization: Codable, Sendable {
    var quotedFee: MoneyAmount
    var maximumFee: MoneyAmount
    var refundAmount: MoneyAmount
    var marketRatePerWeight: UInt64
    var settlementDigest: Data
    var authorizedAt: Date
}

struct DynamicFeeAuthorizationBundle: Codable, Sendable {
    var quote: FeeQuote
    var commitmentProof: FeeCommitmentProof
    var hotkey: AuthorizedFeeHotkey
    var settlement: FeeSettlementAuthorization
}

struct ShieldedWalletSnapshot: Codable, Sendable {
    var network: WalletNetwork
    var notes: [ShieldedNoteWitness]
    var relationships: [TagRelationshipSnapshot]
    var pirSync: PIRSyncSnapshot
    var latestFeeQuote: FeeQuote?

    static let empty = ShieldedWalletSnapshot(
        network: .mainnet,
        notes: [],
        relationships: [],
        pirSync: .empty,
        latestFeeQuote: nil
    )
}

struct ShieldedRecipientPayload: Codable, Sendable {
    var noteCommitment: Data
    var nullifier: Data
    var amount: MoneyAmount
    var memo: String
    var recipientDescriptorID: UUID
    var senderIntroductionEncapsulatedKey: Data?
    var createdAt: Date
}

struct ShieldedSpendSource: Codable, Sendable {
    var noteID: UUID
    var noteCommitment: Data
    var nullifier: Data
    var amount: MoneyAmount
    var merklePath: ShieldedMerklePath
}

struct ShieldedSpendSubmission: Codable, Sendable {
    var draft: SpendDraft
    var authorization: SpendAuthorization
    var source: ShieldedSpendSource
    var destinationDescriptorID: UUID
    var outgoingTag: Data
    var isIntroductionPayment: Bool
    var recipientCiphertext: Data
    var feeAuthorization: DynamicFeeAuthorizationBundle
    var createdAt: Date
}

struct RelaySubmissionReceipt: Codable, Sendable {
    var submissionID: UUID
    var acceptedAt: Date
    var relayDigest: Data
}

struct PIRMerklePathRequest: Codable, Sendable {
    var noteCommitments: [Data]
}

struct PIRMerklePathRecord: Codable, Sendable {
    var noteCommitment: Data
    var path: ShieldedMerklePath
}

struct PIRMerklePathResponse: Codable, Sendable {
    var blockHeight: UInt64
    var paths: [PIRMerklePathRecord]
}

struct PIRNullifierStatusRequest: Codable, Sendable {
    var nullifiers: [Data]
}

struct PIRNullifierStatusResponse: Codable, Sendable {
    var blockHeight: UInt64
    var spentNullifiers: [Data]
}

struct PIRTagLookupRequest: Codable, Sendable {
    var tags: [Data]
}

struct TaggedPaymentMatch: Codable, Sendable {
    var tag: Data
    var recipientDescriptorID: UUID
    var noteCiphertext: Data
    var senderIntroductionEncapsulatedKey: Data?
    var receivedAt: Date
}

struct PIRTagLookupResponse: Codable, Sendable {
    var blockHeight: UInt64
    var matches: [TaggedPaymentMatch]
}

struct FeeQuoteRequest: Codable, Sendable {
    var maximumFee: MoneyAmount
    var confirmationTargetSeconds: Int
}

struct FeeQuoteResponse: Codable, Sendable {
    var quote: FeeQuote
}

struct ShieldedRefreshReport: Sendable {
    var noteCount: Int
    var spendableNoteCount: Int
    var lastKnownBlockHeight: UInt64
    var bandwidth: PIRBandwidthSnapshot
    var readyForImmediateSpend: Bool
}
