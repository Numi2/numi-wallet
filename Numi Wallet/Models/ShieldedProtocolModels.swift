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

enum ShieldedNoteReadinessState: String, Codable, Sendable {
    case discovered
    case verified
    case witnessFresh
    case immediatelySpendable
}

enum ShieldedInboxJournalStage: String, Codable, Sendable {
    case matchReceived
    case deferred
    case payloadDecrypted
    case payloadValidated
    case noteInserted
    case witnessRefreshed
    case spendabilityClassified
    case failed
}

enum TagRelationshipDirection: String, Codable, Sendable {
    case outbound
    case inbound
    case bidirectional
}

enum TagRelationshipState: String, Codable, Sendable {
    case bootstrapPending
    case introductionSent
    case introductionReceived
    case activeBidirectional
    case rotationPending
    case stale
    case revoked
}

enum TagRelationshipIntroductionProvenance: String, Codable, Sendable {
    case outboundBootstrap
    case inboundBootstrap
    case rotatedSuccessor
    case unknown
}

enum ShieldedRefreshTrigger: String, Codable, Sendable {
    case launch
    case foregroundResume
    case backgroundMaintenance
    case preSpend
    case manual
}

struct ShieldedInboxResumptionMaterial: Codable, Hashable, Sendable {
    var matchedTag: Data
    var senderIntroductionEncapsulatedKey: Data?
    var lookaheadStep: Int?
    var decryptedPayload: ShieldedRecipientPayload?
    var decodedNote: TachyonDecodedNote?
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

struct ShieldedInboxJournalEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var stage: ShieldedInboxJournalStage
    var tagDigest: Data
    var ciphertextDigest: Data
    var descriptorID: UUID
    var relationshipID: UUID?
    var noteID: UUID?
    var noteCommitment: Data?
    var receivedAt: Date
    var updatedAt: Date
    var detail: String?
    var resumptionMaterial: ShieldedInboxResumptionMaterial?
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
    var readinessState: ShieldedNoteReadinessState
    var spendState: ShieldedNoteSpendState

    var isSpendable: Bool {
        spendState == .ready && readinessState == .immediatelySpendable
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case tier
        case noteCommitment
        case nullifier
        case amount
        case memo
        case receivedAt
        case descriptorID
        case relationshipID
        case latestTag
        case merklePath
        case lastMerkleUpdateAt
        case lastNullifierCheckAt
        case readinessState
        case spendState
    }

    init(
        id: UUID,
        tier: WalletTier,
        noteCommitment: Data,
        nullifier: Data,
        amount: MoneyAmount,
        memo: String?,
        receivedAt: Date,
        descriptorID: UUID,
        relationshipID: UUID?,
        latestTag: Data?,
        merklePath: ShieldedMerklePath?,
        lastMerkleUpdateAt: Date?,
        lastNullifierCheckAt: Date?,
        readinessState: ShieldedNoteReadinessState,
        spendState: ShieldedNoteSpendState
    ) {
        self.id = id
        self.tier = tier
        self.noteCommitment = noteCommitment
        self.nullifier = nullifier
        self.amount = amount
        self.memo = memo
        self.receivedAt = receivedAt
        self.descriptorID = descriptorID
        self.relationshipID = relationshipID
        self.latestTag = latestTag
        self.merklePath = merklePath
        self.lastMerkleUpdateAt = lastMerkleUpdateAt
        self.lastNullifierCheckAt = lastNullifierCheckAt
        self.readinessState = readinessState
        self.spendState = spendState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let merklePath = try container.decodeIfPresent(ShieldedMerklePath.self, forKey: .merklePath)
        let lastMerkleUpdateAt = try container.decodeIfPresent(Date.self, forKey: .lastMerkleUpdateAt)
        let lastNullifierCheckAt = try container.decodeIfPresent(Date.self, forKey: .lastNullifierCheckAt)
        let spendState = try container.decode(ShieldedNoteSpendState.self, forKey: .spendState)
        let readinessState = try container.decodeIfPresent(ShieldedNoteReadinessState.self, forKey: .readinessState)
            ?? ShieldedNoteWitness.defaultReadinessState(
                spendState: spendState,
                merklePath: merklePath,
                lastMerkleUpdateAt: lastMerkleUpdateAt,
                lastNullifierCheckAt: lastNullifierCheckAt
            )

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            tier: try container.decode(WalletTier.self, forKey: .tier),
            noteCommitment: try container.decode(Data.self, forKey: .noteCommitment),
            nullifier: try container.decode(Data.self, forKey: .nullifier),
            amount: try container.decode(MoneyAmount.self, forKey: .amount),
            memo: try container.decodeIfPresent(String.self, forKey: .memo),
            receivedAt: try container.decode(Date.self, forKey: .receivedAt),
            descriptorID: try container.decode(UUID.self, forKey: .descriptorID),
            relationshipID: try container.decodeIfPresent(UUID.self, forKey: .relationshipID),
            latestTag: try container.decodeIfPresent(Data.self, forKey: .latestTag),
            merklePath: merklePath,
            lastMerkleUpdateAt: lastMerkleUpdateAt,
            lastNullifierCheckAt: lastNullifierCheckAt,
            readinessState: readinessState,
            spendState: spendState
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tier, forKey: .tier)
        try container.encode(noteCommitment, forKey: .noteCommitment)
        try container.encode(nullifier, forKey: .nullifier)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encode(receivedAt, forKey: .receivedAt)
        try container.encode(descriptorID, forKey: .descriptorID)
        try container.encodeIfPresent(relationshipID, forKey: .relationshipID)
        try container.encodeIfPresent(latestTag, forKey: .latestTag)
        try container.encodeIfPresent(merklePath, forKey: .merklePath)
        try container.encodeIfPresent(lastMerkleUpdateAt, forKey: .lastMerkleUpdateAt)
        try container.encodeIfPresent(lastNullifierCheckAt, forKey: .lastNullifierCheckAt)
        try container.encode(readinessState, forKey: .readinessState)
        try container.encode(spendState, forKey: .spendState)
    }

    private static func defaultReadinessState(
        spendState: ShieldedNoteSpendState,
        merklePath: ShieldedMerklePath?,
        lastMerkleUpdateAt: Date?,
        lastNullifierCheckAt: Date?
    ) -> ShieldedNoteReadinessState {
        if spendState == .ready, merklePath != nil, lastMerkleUpdateAt != nil {
            return .immediatelySpendable
        }
        if merklePath != nil {
            return .witnessFresh
        }
        if lastNullifierCheckAt != nil {
            return .verified
        }
        return .discovered
    }
}

struct TagRelationshipSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var alias: String?
    var peerDescriptorID: UUID
    var peerTaggingPublicKey: Data
    var introductionEncapsulatedKey: Data?
    var direction: TagRelationshipDirection
    var state: TagRelationshipState
    var nextOutgoingCounter: UInt64
    var nextIncomingCounter: UInt64
    var lookaheadWindowSize: Int
    var lastIssuedIncomingLookaheadCounter: UInt64
    var lastAcceptedIncomingTagDigest: Data?
    var acceptedIncomingTagDigests: [Data]
    var acceptedCiphertextDigests: [Data]
    var introductionProvenance: TagRelationshipIntroductionProvenance
    var rotationTargetDescriptorID: UUID?
    var establishedAt: Date
    var lastActivityAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case alias
        case peerDescriptorID
        case peerTaggingPublicKey
        case introductionEncapsulatedKey
        case direction
        case state
        case nextOutgoingCounter
        case nextIncomingCounter
        case lookaheadWindowSize
        case lastIssuedIncomingLookaheadCounter
        case lastAcceptedIncomingTagDigest
        case acceptedIncomingTagDigests
        case acceptedCiphertextDigests
        case introductionProvenance
        case rotationTargetDescriptorID
        case establishedAt
        case lastActivityAt
    }

    init(
        id: UUID,
        alias: String?,
        peerDescriptorID: UUID,
        peerTaggingPublicKey: Data,
        introductionEncapsulatedKey: Data?,
        direction: TagRelationshipDirection,
        state: TagRelationshipState,
        nextOutgoingCounter: UInt64,
        nextIncomingCounter: UInt64,
        lookaheadWindowSize: Int,
        lastIssuedIncomingLookaheadCounter: UInt64,
        lastAcceptedIncomingTagDigest: Data?,
        acceptedIncomingTagDigests: [Data],
        acceptedCiphertextDigests: [Data],
        introductionProvenance: TagRelationshipIntroductionProvenance,
        rotationTargetDescriptorID: UUID?,
        establishedAt: Date,
        lastActivityAt: Date?
    ) {
        self.id = id
        self.alias = alias
        self.peerDescriptorID = peerDescriptorID
        self.peerTaggingPublicKey = peerTaggingPublicKey
        self.introductionEncapsulatedKey = introductionEncapsulatedKey
        self.direction = direction
        self.state = state
        self.nextOutgoingCounter = nextOutgoingCounter
        self.nextIncomingCounter = nextIncomingCounter
        self.lookaheadWindowSize = lookaheadWindowSize
        self.lastIssuedIncomingLookaheadCounter = lastIssuedIncomingLookaheadCounter
        self.lastAcceptedIncomingTagDigest = lastAcceptedIncomingTagDigest
        self.acceptedIncomingTagDigests = acceptedIncomingTagDigests
        self.acceptedCiphertextDigests = acceptedCiphertextDigests
        self.introductionProvenance = introductionProvenance
        self.rotationTargetDescriptorID = rotationTargetDescriptorID
        self.establishedAt = establishedAt
        self.lastActivityAt = lastActivityAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let direction = try container.decode(TagRelationshipDirection.self, forKey: .direction)
        let nextOutgoingCounter = try container.decodeIfPresent(UInt64.self, forKey: .nextOutgoingCounter) ?? 0
        let nextIncomingCounter = try container.decodeIfPresent(UInt64.self, forKey: .nextIncomingCounter) ?? 0
        let state = try container.decodeIfPresent(TagRelationshipState.self, forKey: .state)
            ?? TagRelationshipSnapshot.defaultState(
                direction: direction,
                nextOutgoingCounter: nextOutgoingCounter,
                nextIncomingCounter: nextIncomingCounter,
                introductionEncapsulatedKey: try container.decodeIfPresent(Data.self, forKey: .introductionEncapsulatedKey)
            )
        let lookaheadWindowSize = try container.decodeIfPresent(Int.self, forKey: .lookaheadWindowSize) ?? 4

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            alias: try container.decodeIfPresent(String.self, forKey: .alias),
            peerDescriptorID: try container.decode(UUID.self, forKey: .peerDescriptorID),
            peerTaggingPublicKey: try container.decodeIfPresent(Data.self, forKey: .peerTaggingPublicKey) ?? Data(),
            introductionEncapsulatedKey: try container.decodeIfPresent(Data.self, forKey: .introductionEncapsulatedKey),
            direction: direction,
            state: state,
            nextOutgoingCounter: nextOutgoingCounter,
            nextIncomingCounter: nextIncomingCounter,
            lookaheadWindowSize: lookaheadWindowSize,
            lastIssuedIncomingLookaheadCounter: try container.decodeIfPresent(UInt64.self, forKey: .lastIssuedIncomingLookaheadCounter)
                ?? (nextIncomingCounter + UInt64(max(lookaheadWindowSize, 0))),
            lastAcceptedIncomingTagDigest: try container.decodeIfPresent(Data.self, forKey: .lastAcceptedIncomingTagDigest),
            acceptedIncomingTagDigests: try container.decodeIfPresent([Data].self, forKey: .acceptedIncomingTagDigests) ?? [],
            acceptedCiphertextDigests: try container.decodeIfPresent([Data].self, forKey: .acceptedCiphertextDigests) ?? [],
            introductionProvenance: try container.decodeIfPresent(TagRelationshipIntroductionProvenance.self, forKey: .introductionProvenance)
                ?? TagRelationshipSnapshot.defaultIntroductionProvenance(for: direction),
            rotationTargetDescriptorID: try container.decodeIfPresent(UUID.self, forKey: .rotationTargetDescriptorID),
            establishedAt: try container.decode(Date.self, forKey: .establishedAt),
            lastActivityAt: try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(alias, forKey: .alias)
        try container.encode(peerDescriptorID, forKey: .peerDescriptorID)
        try container.encode(peerTaggingPublicKey, forKey: .peerTaggingPublicKey)
        try container.encodeIfPresent(introductionEncapsulatedKey, forKey: .introductionEncapsulatedKey)
        try container.encode(direction, forKey: .direction)
        try container.encode(state, forKey: .state)
        try container.encode(nextOutgoingCounter, forKey: .nextOutgoingCounter)
        try container.encode(nextIncomingCounter, forKey: .nextIncomingCounter)
        try container.encode(lookaheadWindowSize, forKey: .lookaheadWindowSize)
        try container.encode(lastIssuedIncomingLookaheadCounter, forKey: .lastIssuedIncomingLookaheadCounter)
        try container.encodeIfPresent(lastAcceptedIncomingTagDigest, forKey: .lastAcceptedIncomingTagDigest)
        try container.encode(acceptedIncomingTagDigests, forKey: .acceptedIncomingTagDigests)
        try container.encode(acceptedCiphertextDigests, forKey: .acceptedCiphertextDigests)
        try container.encode(introductionProvenance, forKey: .introductionProvenance)
        try container.encodeIfPresent(rotationTargetDescriptorID, forKey: .rotationTargetDescriptorID)
        try container.encode(establishedAt, forKey: .establishedAt)
        try container.encodeIfPresent(lastActivityAt, forKey: .lastActivityAt)
    }

    private static func defaultState(
        direction: TagRelationshipDirection,
        nextOutgoingCounter: UInt64,
        nextIncomingCounter: UInt64,
        introductionEncapsulatedKey: Data?
    ) -> TagRelationshipState {
        if direction == .bidirectional || (nextOutgoingCounter > 0 && nextIncomingCounter > 0) {
            return .activeBidirectional
        }
        if direction == .outbound || nextOutgoingCounter > 0 {
            return introductionEncapsulatedKey == nil ? .bootstrapPending : .introductionSent
        }
        if direction == .inbound || nextIncomingCounter > 0 {
            return .introductionReceived
        }
        return .bootstrapPending
    }

    private static func defaultIntroductionProvenance(for direction: TagRelationshipDirection) -> TagRelationshipIntroductionProvenance {
        switch direction {
        case .outbound, .bidirectional:
            return .outboundBootstrap
        case .inbound:
            return .inboundBootstrap
        }
    }
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

enum PIRQueryClass: String, Codable, CaseIterable, Sendable {
    case merklePaths
    case nullifierStatuses
    case tagDiscovery
    case contactDocuments
}

enum PIRProviderPolicyKind: String, Codable, Sendable {
    case singleProvider
    case compareTwo
    case quorum
}

enum PIRReadinessClassification: String, Codable, Sendable {
    case ready
    case stale
    case degraded
    case disputed

    var displayName: String {
        switch self {
        case .ready:
            return "Ready"
        case .stale:
            return "Stale"
        case .degraded:
            return "Degraded"
        case .disputed:
            return "Disputed"
        }
    }
}

struct PIRProviderIdentity: Codable, Hashable, Sendable {
    var id: String
    var displayName: String
    var serviceOrigin: String
}

struct PIRQueryPolicy: Codable, Hashable, Sendable {
    var queryClass: PIRQueryClass
    var strategy: PIRProviderPolicyKind
    var requiredProviderCount: Int

    static var defaultPolicies: [PIRQueryPolicy] {
        PIRQueryClass.allCases.map { queryClass in
            PIRQueryPolicy(queryClass: queryClass, strategy: .singleProvider, requiredProviderCount: 1)
        }
    }
}

struct PIRQueryReceipt: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var queryClass: PIRQueryClass
    var providerID: String
    var requestDigest: Data
    var responseDigest: Data
    var responseItemCount: Int
    var blockHeight: UInt64
    var anchorRoot: Data?
    var receivedAt: Date
}

struct PIRMismatchEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var queryClass: PIRQueryClass
    var providerIDs: [String]
    var reason: String
    var expectedDigest: Data?
    var observedDigest: Data?
    var expectedBlockHeight: UInt64?
    var observedBlockHeight: UInt64?
    var recordedAt: Date
}

struct PIRDisputeEvidenceSnapshot: Codable, Hashable, Sendable {
    var capturedAt: Date
    var queryReceipts: [PIRQueryReceipt]
    var mismatchEvents: [PIRMismatchEvent]
    var noteCommitmentDigests: [Data]
    var nullifierDigests: [Data]
    var tagDigests: [Data]
}

struct PIRReadinessLease: Codable, Hashable, Sendable {
    var classification: PIRReadinessClassification
    var issuedAt: Date
    var expiresAt: Date
    var trustedBlockHeight: UInt64
    var anchorRoot: Data?
    var providerIDs: [String]
    var ticketLedgerDigest: Data
    var evidenceDigest: Data?
    var detail: String

    var permitsImmediateSpend: Bool {
        classification == .ready && Date() <= expiresAt
    }
}

struct PIRRefreshTicket: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var queryClass: PIRQueryClass
    var ticketDigest: Data
    var descriptorID: UUID?
    var relationshipID: UUID?
    var noteID: UUID?
    var noteCommitment: Data?
    var nullifier: Data?
    var tag: Data?
    var lookaheadStep: Int?
    var createdAt: Date
    var expiresAt: Date
}

struct PIRRefreshTicketLedger: Codable, Hashable, Sendable {
    var generatedAt: Date
    var expiresAt: Date
    var tickets: [PIRRefreshTicket]
    var digest: Data
}

struct PIRSyncSnapshot: Codable, Sendable {
    var lastRefreshAt: Date?
    var lastKnownBlockHeight: UInt64
    var lastBandwidth: PIRBandwidthSnapshot
    var readyForImmediateSpend: Bool
    var lastError: String?
    var readinessClassification: PIRReadinessClassification
    var queryPolicies: [PIRQueryPolicy]
    var providers: [PIRProviderIdentity]
    var recentReceipts: [PIRQueryReceipt]
    var mismatchEvents: [PIRMismatchEvent]
    var disputeEvidence: PIRDisputeEvidenceSnapshot?
    var readinessLease: PIRReadinessLease?
    var refreshTicketLedger: PIRRefreshTicketLedger?

    private enum CodingKeys: String, CodingKey {
        case lastRefreshAt
        case lastKnownBlockHeight
        case lastBandwidth
        case readyForImmediateSpend
        case lastError
        case readinessClassification
        case queryPolicies
        case providers
        case recentReceipts
        case mismatchEvents
        case disputeEvidence
        case readinessLease
        case refreshTicketLedger
    }

    static let empty = PIRSyncSnapshot(
        lastRefreshAt: nil,
        lastKnownBlockHeight: 0,
        lastBandwidth: .zero,
        readyForImmediateSpend: false,
        lastError: nil,
        readinessClassification: .stale,
        queryPolicies: PIRQueryPolicy.defaultPolicies,
        providers: [],
        recentReceipts: [],
        mismatchEvents: [],
        disputeEvidence: nil,
        readinessLease: nil,
        refreshTicketLedger: nil
    )

    init(
        lastRefreshAt: Date?,
        lastKnownBlockHeight: UInt64,
        lastBandwidth: PIRBandwidthSnapshot,
        readyForImmediateSpend: Bool,
        lastError: String?,
        readinessClassification: PIRReadinessClassification,
        queryPolicies: [PIRQueryPolicy],
        providers: [PIRProviderIdentity],
        recentReceipts: [PIRQueryReceipt],
        mismatchEvents: [PIRMismatchEvent],
        disputeEvidence: PIRDisputeEvidenceSnapshot?,
        readinessLease: PIRReadinessLease?,
        refreshTicketLedger: PIRRefreshTicketLedger?
    ) {
        self.lastRefreshAt = lastRefreshAt
        self.lastKnownBlockHeight = lastKnownBlockHeight
        self.lastBandwidth = lastBandwidth
        self.readyForImmediateSpend = readyForImmediateSpend
        self.lastError = lastError
        self.readinessClassification = readinessClassification
        self.queryPolicies = queryPolicies
        self.providers = providers
        self.recentReceipts = recentReceipts
        self.mismatchEvents = mismatchEvents
        self.disputeEvidence = disputeEvidence
        self.readinessLease = readinessLease
        self.refreshTicketLedger = refreshTicketLedger
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readyForImmediateSpend = try container.decodeIfPresent(Bool.self, forKey: .readyForImmediateSpend) ?? false
        let lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        let readinessClassification = try container.decodeIfPresent(PIRReadinessClassification.self, forKey: .readinessClassification)
            ?? PIRSyncSnapshot.defaultClassification(
                readyForImmediateSpend: readyForImmediateSpend,
                lastError: lastError
            )

        self.init(
            lastRefreshAt: try container.decodeIfPresent(Date.self, forKey: .lastRefreshAt),
            lastKnownBlockHeight: try container.decodeIfPresent(UInt64.self, forKey: .lastKnownBlockHeight) ?? 0,
            lastBandwidth: try container.decodeIfPresent(PIRBandwidthSnapshot.self, forKey: .lastBandwidth) ?? .zero,
            readyForImmediateSpend: readyForImmediateSpend,
            lastError: lastError,
            readinessClassification: readinessClassification,
            queryPolicies: try container.decodeIfPresent([PIRQueryPolicy].self, forKey: .queryPolicies) ?? PIRQueryPolicy.defaultPolicies,
            providers: try container.decodeIfPresent([PIRProviderIdentity].self, forKey: .providers) ?? [],
            recentReceipts: try container.decodeIfPresent([PIRQueryReceipt].self, forKey: .recentReceipts) ?? [],
            mismatchEvents: try container.decodeIfPresent([PIRMismatchEvent].self, forKey: .mismatchEvents) ?? [],
            disputeEvidence: try container.decodeIfPresent(PIRDisputeEvidenceSnapshot.self, forKey: .disputeEvidence),
            readinessLease: try container.decodeIfPresent(PIRReadinessLease.self, forKey: .readinessLease),
            refreshTicketLedger: try container.decodeIfPresent(PIRRefreshTicketLedger.self, forKey: .refreshTicketLedger)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lastRefreshAt, forKey: .lastRefreshAt)
        try container.encode(lastKnownBlockHeight, forKey: .lastKnownBlockHeight)
        try container.encode(lastBandwidth, forKey: .lastBandwidth)
        try container.encode(readyForImmediateSpend, forKey: .readyForImmediateSpend)
        try container.encodeIfPresent(lastError, forKey: .lastError)
        try container.encode(readinessClassification, forKey: .readinessClassification)
        try container.encode(queryPolicies, forKey: .queryPolicies)
        try container.encode(providers, forKey: .providers)
        try container.encode(recentReceipts, forKey: .recentReceipts)
        try container.encode(mismatchEvents, forKey: .mismatchEvents)
        try container.encodeIfPresent(disputeEvidence, forKey: .disputeEvidence)
        try container.encodeIfPresent(readinessLease, forKey: .readinessLease)
        try container.encodeIfPresent(refreshTicketLedger, forKey: .refreshTicketLedger)
    }

    private static func defaultClassification(
        readyForImmediateSpend: Bool,
        lastError: String?
    ) -> PIRReadinessClassification {
        if lastError != nil {
            return .degraded
        }
        return readyForImmediateSpend ? .ready : .stale
    }
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
    var inboxJournal: [ShieldedInboxJournalEntry]
    var pirSync: PIRSyncSnapshot
    var pendingProofs: [TachyonProofCheckpoint]
    var latestFeeQuote: FeeQuote?

    private enum CodingKeys: String, CodingKey {
        case network
        case notes
        case relationships
        case inboxJournal
        case pirSync
        case pendingProofs
        case latestFeeQuote
    }

    static let empty = ShieldedWalletSnapshot(
        network: .mainnet,
        notes: [],
        relationships: [],
        inboxJournal: [],
        pirSync: .empty,
        pendingProofs: [],
        latestFeeQuote: nil
    )

    init(
        network: WalletNetwork,
        notes: [ShieldedNoteWitness],
        relationships: [TagRelationshipSnapshot],
        inboxJournal: [ShieldedInboxJournalEntry],
        pirSync: PIRSyncSnapshot,
        pendingProofs: [TachyonProofCheckpoint],
        latestFeeQuote: FeeQuote?
    ) {
        self.network = network
        self.notes = notes
        self.relationships = relationships
        self.inboxJournal = inboxJournal
        self.pirSync = pirSync
        self.pendingProofs = pendingProofs
        self.latestFeeQuote = latestFeeQuote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            network: try container.decode(WalletNetwork.self, forKey: .network),
            notes: try container.decodeIfPresent([ShieldedNoteWitness].self, forKey: .notes) ?? [],
            relationships: try container.decodeIfPresent([TagRelationshipSnapshot].self, forKey: .relationships) ?? [],
            inboxJournal: try container.decodeIfPresent([ShieldedInboxJournalEntry].self, forKey: .inboxJournal) ?? [],
            pirSync: try container.decodeIfPresent(PIRSyncSnapshot.self, forKey: .pirSync) ?? .empty,
            pendingProofs: try container.decodeIfPresent([TachyonProofCheckpoint].self, forKey: .pendingProofs) ?? [],
            latestFeeQuote: try container.decodeIfPresent(FeeQuote.self, forKey: .latestFeeQuote)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(network, forKey: .network)
        try container.encode(notes, forKey: .notes)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(inboxJournal, forKey: .inboxJournal)
        try container.encode(pirSync, forKey: .pirSync)
        try container.encode(pendingProofs, forKey: .pendingProofs)
        try container.encodeIfPresent(latestFeeQuote, forKey: .latestFeeQuote)
    }
}

struct ShieldedRecipientPayload: Codable, Hashable, Sendable {
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
    var tachyonEnvelope: TachyonSubmissionEnvelope?
    var tachyonProofArtifact: TachyonProofArtifact?
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
    var discoveredNoteCount: Int
    var verifiedNoteCount: Int
    var witnessFreshNoteCount: Int
    var spendableNoteCount: Int
    var lastKnownBlockHeight: UInt64
    var bandwidth: PIRBandwidthSnapshot
    var readyForImmediateSpend: Bool
    var readinessClassification: PIRReadinessClassification
    var leaseExpiresAt: Date?
    var mismatchCount: Int
    var deferredMatchCount: Int
}
