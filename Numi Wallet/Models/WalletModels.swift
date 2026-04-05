import CryptoKit
import Foundation

enum DeviceRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case authorityPhone
    case recoveryPad
    case recoveryMac

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .authorityPhone:
            return "Authority iPhone"
        case .recoveryPad:
            return "Recovery iPad"
        case .recoveryMac:
            return "Recovery Mac"
        }
    }

    var isAuthority: Bool { self == .authorityPhone }
    var isRecoveryPeer: Bool { !isAuthority }
}

enum WalletTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case day
    case vault

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day:
            return "Day Wallet"
        case .vault:
            return "Vault Wallet"
        }
    }
}

enum ProofPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case onDeviceOnly
    case pairedMacPreferred

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onDeviceOnly:
            return "On Device Only"
        case .pairedMacPreferred:
            return "Prefer Paired Mac"
        }
    }
}

enum PanicState: String, Codable, Sendable {
    case normal
    case localUnwrapDestroyed
}

enum PeerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mac
    case pad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mac:
            return "Mac"
        case .pad:
            return "iPad"
        }
    }
}

enum EnvelopeKind: String, Codable, Sendable {
    case discoveryLookup
    case discoveryRegistration
    case relaySubmission
    case relayBatchProbe
    case pirMerklePaths
    case pirNullifiers
    case pirTags
    case feeQuote
}

enum PairingTransport: String, Codable, Sendable {
    case nearbyInteraction
    case networkFramework
}

struct MoneyAmount: Codable, Hashable, Sendable {
    var minorUnits: Int64
    var currencyCode: String

    static let zero = MoneyAmount(minorUnits: 0, currencyCode: "NUMI")

    func formatted() -> String {
        let major = Double(minorUnits) / 100.0
        return "\(currencyCode) \(major.formatted(.number.precision(.fractionLength(2))))"
    }
}

struct ShieldedNoteSummary: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var amount: MoneyAmount
    var createdAt: Date
    var memo: String?
}

struct PairedPeer: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: PeerKind
    var deviceID: String
    var lastSeenAt: Date?
    var supportsNearbyInteraction: Bool
    var supportsProofOffload: Bool
}

struct PrivateReceiveDescriptor: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var tier: WalletTier
    var rotation: UInt64
    var createdAt: Date
    var expiresAt: Date
    var aliasHint: String?
    var deliveryCurve25519PublicKey: Data
    var taggingCurve25519PublicKey: Data
    var offlineToken: Data
    var issuerIdentity: Data
    var signature: Data

    private enum CodingKeys: String, CodingKey {
        case id
        case tier
        case rotation
        case createdAt
        case expiresAt
        case aliasHint
        case deliveryCurve25519PublicKey
        case taggingCurve25519PublicKey
        case offlineToken
        case issuerIdentity
        case signature
    }

    init(
        id: UUID,
        tier: WalletTier,
        rotation: UInt64,
        createdAt: Date,
        expiresAt: Date,
        aliasHint: String?,
        deliveryCurve25519PublicKey: Data,
        taggingCurve25519PublicKey: Data,
        offlineToken: Data,
        issuerIdentity: Data,
        signature: Data
    ) {
        self.id = id
        self.tier = tier
        self.rotation = rotation
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.aliasHint = aliasHint
        self.deliveryCurve25519PublicKey = deliveryCurve25519PublicKey
        self.taggingCurve25519PublicKey = taggingCurve25519PublicKey
        self.offlineToken = offlineToken
        self.issuerIdentity = issuerIdentity
        self.signature = signature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            tier: try container.decode(WalletTier.self, forKey: .tier),
            rotation: try container.decode(UInt64.self, forKey: .rotation),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            expiresAt: try container.decode(Date.self, forKey: .expiresAt),
            aliasHint: try container.decodeIfPresent(String.self, forKey: .aliasHint),
            deliveryCurve25519PublicKey: try container.decode(Data.self, forKey: .deliveryCurve25519PublicKey),
            taggingCurve25519PublicKey: try container.decodeIfPresent(Data.self, forKey: .taggingCurve25519PublicKey) ?? Data(),
            offlineToken: try container.decode(Data.self, forKey: .offlineToken),
            issuerIdentity: try container.decode(Data.self, forKey: .issuerIdentity),
            signature: try container.decode(Data.self, forKey: .signature)
        )
    }

    var fingerprint: String {
        let digest = SHA256.hash(data: signature)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}

struct DayWalletSnapshot: Codable, Sendable {
    var balance: MoneyAmount
    var alias: String?
    var activeDescriptor: PrivateReceiveDescriptor?
    var pendingNotes: [ShieldedNoteSummary]
    var descriptorKeyIDs: [UUID]
    var legacyDescriptorPrivateKeys: [UUID: Data]?

    private enum CodingKeys: String, CodingKey {
        case balance
        case alias
        case activeDescriptor
        case pendingNotes
        case descriptorKeyIDs
        case descriptorPrivateKeys
    }

    static let empty = DayWalletSnapshot(
        balance: .zero,
        alias: nil,
        activeDescriptor: nil,
        pendingNotes: [],
        descriptorKeyIDs: [],
        legacyDescriptorPrivateKeys: nil
    )

    mutating func registerDescriptorKey(_ descriptorID: UUID) {
        if !descriptorKeyIDs.contains(descriptorID) {
            descriptorKeyIDs.append(descriptorID)
        }
    }

    mutating func consumeLegacyDescriptorPrivateKeys() -> [UUID: Data] {
        let secrets = legacyDescriptorPrivateKeys ?? [:]
        for descriptorID in secrets.keys where !descriptorKeyIDs.contains(descriptorID) {
            descriptorKeyIDs.append(descriptorID)
        }
        legacyDescriptorPrivateKeys = nil
        return secrets
    }

    init(
        balance: MoneyAmount,
        alias: String?,
        activeDescriptor: PrivateReceiveDescriptor?,
        pendingNotes: [ShieldedNoteSummary],
        descriptorKeyIDs: [UUID],
        legacyDescriptorPrivateKeys: [UUID: Data]? = nil
    ) {
        self.balance = balance
        self.alias = alias
        self.activeDescriptor = activeDescriptor
        self.pendingNotes = pendingNotes
        self.descriptorKeyIDs = descriptorKeyIDs
        self.legacyDescriptorPrivateKeys = legacyDescriptorPrivateKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyDescriptorPrivateKeys = try container.decodeIfPresent([UUID: Data].self, forKey: .descriptorPrivateKeys)
        let descriptorKeyIDs = try container.decodeIfPresent([UUID].self, forKey: .descriptorKeyIDs)
            ?? Array((legacyDescriptorPrivateKeys ?? [:]).keys)

        self.init(
            balance: try container.decode(MoneyAmount.self, forKey: .balance),
            alias: try container.decodeIfPresent(String.self, forKey: .alias),
            activeDescriptor: try container.decodeIfPresent(PrivateReceiveDescriptor.self, forKey: .activeDescriptor),
            pendingNotes: try container.decodeIfPresent([ShieldedNoteSummary].self, forKey: .pendingNotes) ?? [],
            descriptorKeyIDs: descriptorKeyIDs,
            legacyDescriptorPrivateKeys: legacyDescriptorPrivateKeys
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(balance, forKey: .balance)
        try container.encodeIfPresent(alias, forKey: .alias)
        try container.encodeIfPresent(activeDescriptor, forKey: .activeDescriptor)
        try container.encode(pendingNotes, forKey: .pendingNotes)
        try container.encode(descriptorKeyIDs, forKey: .descriptorKeyIDs)
    }
}

struct VaultWalletSnapshot: Codable, Sendable {
    var balance: MoneyAmount
    var activeDescriptor: PrivateReceiveDescriptor?
    var notes: [ShieldedNoteSummary]
    var descriptorKeyIDs: [UUID]
    var lastUnlockedAt: Date?
    var legacyDescriptorPrivateKeys: [UUID: Data]?

    private enum CodingKeys: String, CodingKey {
        case balance
        case activeDescriptor
        case notes
        case descriptorKeyIDs
        case descriptorPrivateKeys
        case lastUnlockedAt
    }

    static let empty = VaultWalletSnapshot(
        balance: .zero,
        activeDescriptor: nil,
        notes: [],
        descriptorKeyIDs: [],
        lastUnlockedAt: nil,
        legacyDescriptorPrivateKeys: nil
    )

    mutating func registerDescriptorKey(_ descriptorID: UUID) {
        if !descriptorKeyIDs.contains(descriptorID) {
            descriptorKeyIDs.append(descriptorID)
        }
    }

    mutating func consumeLegacyDescriptorPrivateKeys() -> [UUID: Data] {
        let secrets = legacyDescriptorPrivateKeys ?? [:]
        for descriptorID in secrets.keys where !descriptorKeyIDs.contains(descriptorID) {
            descriptorKeyIDs.append(descriptorID)
        }
        legacyDescriptorPrivateKeys = nil
        return secrets
    }

    init(
        balance: MoneyAmount,
        activeDescriptor: PrivateReceiveDescriptor?,
        notes: [ShieldedNoteSummary],
        descriptorKeyIDs: [UUID],
        lastUnlockedAt: Date?,
        legacyDescriptorPrivateKeys: [UUID: Data]? = nil
    ) {
        self.balance = balance
        self.activeDescriptor = activeDescriptor
        self.notes = notes
        self.descriptorKeyIDs = descriptorKeyIDs
        self.lastUnlockedAt = lastUnlockedAt
        self.legacyDescriptorPrivateKeys = legacyDescriptorPrivateKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyDescriptorPrivateKeys = try container.decodeIfPresent([UUID: Data].self, forKey: .descriptorPrivateKeys)
        let descriptorKeyIDs = try container.decodeIfPresent([UUID].self, forKey: .descriptorKeyIDs)
            ?? Array((legacyDescriptorPrivateKeys ?? [:]).keys)

        self.init(
            balance: try container.decode(MoneyAmount.self, forKey: .balance),
            activeDescriptor: try container.decodeIfPresent(PrivateReceiveDescriptor.self, forKey: .activeDescriptor),
            notes: try container.decodeIfPresent([ShieldedNoteSummary].self, forKey: .notes) ?? [],
            descriptorKeyIDs: descriptorKeyIDs,
            lastUnlockedAt: try container.decodeIfPresent(Date.self, forKey: .lastUnlockedAt),
            legacyDescriptorPrivateKeys: legacyDescriptorPrivateKeys
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(balance, forKey: .balance)
        try container.encodeIfPresent(activeDescriptor, forKey: .activeDescriptor)
        try container.encode(notes, forKey: .notes)
        try container.encode(descriptorKeyIDs, forKey: .descriptorKeyIDs)
        try container.encodeIfPresent(lastUnlockedAt, forKey: .lastUnlockedAt)
    }
}

struct EncryptedVaultBlob: Codable, Sendable {
    var ciphertext: Data
    var updatedAt: Date
}

struct RecoveryPackage: Codable, Sendable {
    var packageID: UUID
    var sealedState: Data
    var createdAt: Date
    var stateDigest: Data
}

struct RecoveryShareEnvelope: Codable, Identifiable, Sendable {
    var id: UUID
    var peerName: String
    var peerKind: PeerKind
    var deviceID: String
    var fragment: Data
    var recoveryPackage: RecoveryPackage
    var rootKeyDigest: Data
    var createdAt: Date
}

struct RecoveryPeerRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var peerName: String
    var peerKind: PeerKind
    var deviceID: String
    var rootKeyDigest: Data
    var createdAt: Date
}

struct PolicySnapshot: Codable, Sendable {
    var requirePeerForVaultVisibility: Bool
    var requirePeerForVaultSpend: Bool
    var allowCompanionSpendApproval: Bool
    var proofPolicy: ProofPolicy
    var panicState: PanicState
    var lockVaultOnBackground: Bool
    var redactSensitiveUIOnBackground: Bool
    var redactSensitiveUIOnCapture: Bool

    static let `default` = PolicySnapshot(
        requirePeerForVaultVisibility: true,
        requirePeerForVaultSpend: true,
        allowCompanionSpendApproval: false,
        proofPolicy: .onDeviceOnly,
        panicState: .normal,
        lockVaultOnBackground: true,
        redactSensitiveUIOnBackground: true,
        redactSensitiveUIOnCapture: true
    )
}

struct WalletProfile: Codable, Sendable {
    var version: Int
    var deviceID: String
    var role: DeviceRole
    var createdAt: Date
    var rootPublicIdentity: Data?
    var dayWallet: DayWalletSnapshot?
    var encryptedVault: EncryptedVaultBlob?
    var publicVaultDescriptor: PrivateReceiveDescriptor?
    var policy: PolicySnapshot
    var peers: [PairedPeer]
    var recoveryPackage: RecoveryPackage?
    var recoveryPeers: [RecoveryPeerRecord]
    var shielded: ShieldedWalletSnapshot
    var lastDayUnlockAt: Date?
    var lastVaultUnlockAt: Date?
    var attestedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case version
        case deviceID
        case role
        case createdAt
        case rootPublicIdentity
        case dayWallet
        case encryptedVault
        case publicVaultDescriptor
        case policy
        case peers
        case recoveryPackage
        case recoveryPeers
        case recoveryShares
        case shielded
        case lastDayUnlockAt
        case lastVaultUnlockAt
        case attestedAt
    }

    static func empty(deviceID: String, role: DeviceRole) -> WalletProfile {
        WalletProfile(
            version: 3,
            deviceID: deviceID,
            role: role,
            createdAt: Date(),
            rootPublicIdentity: nil,
            dayWallet: nil,
            encryptedVault: nil,
            publicVaultDescriptor: nil,
            policy: .default,
            peers: [],
            recoveryPackage: nil,
            recoveryPeers: [],
            shielded: .empty,
            lastDayUnlockAt: nil,
            lastVaultUnlockAt: nil,
            attestedAt: nil
        )
    }

    init(
        version: Int,
        deviceID: String,
        role: DeviceRole,
        createdAt: Date,
        rootPublicIdentity: Data?,
        dayWallet: DayWalletSnapshot?,
        encryptedVault: EncryptedVaultBlob?,
        publicVaultDescriptor: PrivateReceiveDescriptor?,
        policy: PolicySnapshot,
        peers: [PairedPeer],
        recoveryPackage: RecoveryPackage?,
        recoveryPeers: [RecoveryPeerRecord],
        shielded: ShieldedWalletSnapshot,
        lastDayUnlockAt: Date?,
        lastVaultUnlockAt: Date?,
        attestedAt: Date?
    ) {
        self.version = version
        self.deviceID = deviceID
        self.role = role
        self.createdAt = createdAt
        self.rootPublicIdentity = rootPublicIdentity
        self.dayWallet = dayWallet
        self.encryptedVault = encryptedVault
        self.publicVaultDescriptor = publicVaultDescriptor
        self.policy = policy
        self.peers = peers
        self.recoveryPackage = recoveryPackage
        self.recoveryPeers = recoveryPeers
        self.shielded = shielded
        self.lastDayUnlockAt = lastDayUnlockAt
        self.lastVaultUnlockAt = lastVaultUnlockAt
        self.attestedAt = attestedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyShares = try container.decodeIfPresent([RecoveryShareEnvelope].self, forKey: .recoveryShares) ?? []
        let decodedRecoveryPeers = try container.decodeIfPresent([RecoveryPeerRecord].self, forKey: .recoveryPeers)

        self.init(
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? 1,
            deviceID: try container.decode(String.self, forKey: .deviceID),
            role: try container.decode(DeviceRole.self, forKey: .role),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            rootPublicIdentity: try container.decodeIfPresent(Data.self, forKey: .rootPublicIdentity),
            dayWallet: try container.decodeIfPresent(DayWalletSnapshot.self, forKey: .dayWallet),
            encryptedVault: try container.decodeIfPresent(EncryptedVaultBlob.self, forKey: .encryptedVault),
            publicVaultDescriptor: try container.decodeIfPresent(PrivateReceiveDescriptor.self, forKey: .publicVaultDescriptor),
            policy: try container.decode(PolicySnapshot.self, forKey: .policy),
            peers: try container.decodeIfPresent([PairedPeer].self, forKey: .peers) ?? [],
            recoveryPackage: try container.decodeIfPresent(RecoveryPackage.self, forKey: .recoveryPackage),
            recoveryPeers: decodedRecoveryPeers ?? legacyShares.map {
                RecoveryPeerRecord(
                    id: $0.id,
                    peerName: $0.peerName,
                    peerKind: $0.peerKind,
                    deviceID: $0.deviceID,
                    rootKeyDigest: $0.rootKeyDigest,
                    createdAt: $0.createdAt
                )
            },
            shielded: try container.decodeIfPresent(ShieldedWalletSnapshot.self, forKey: .shielded) ?? .empty,
            lastDayUnlockAt: try container.decodeIfPresent(Date.self, forKey: .lastDayUnlockAt),
            lastVaultUnlockAt: try container.decodeIfPresent(Date.self, forKey: .lastVaultUnlockAt),
            attestedAt: try container.decodeIfPresent(Date.self, forKey: .attestedAt)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(role, forKey: .role)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(rootPublicIdentity, forKey: .rootPublicIdentity)
        try container.encodeIfPresent(dayWallet, forKey: .dayWallet)
        try container.encodeIfPresent(encryptedVault, forKey: .encryptedVault)
        try container.encodeIfPresent(publicVaultDescriptor, forKey: .publicVaultDescriptor)
        try container.encode(policy, forKey: .policy)
        try container.encode(peers, forKey: .peers)
        try container.encodeIfPresent(recoveryPackage, forKey: .recoveryPackage)
        try container.encode(recoveryPeers, forKey: .recoveryPeers)
        try container.encode(shielded, forKey: .shielded)
        try container.encodeIfPresent(lastDayUnlockAt, forKey: .lastDayUnlockAt)
        try container.encodeIfPresent(lastVaultUnlockAt, forKey: .lastVaultUnlockAt)
        try container.encodeIfPresent(attestedAt, forKey: .attestedAt)
    }
}

struct SpendDraft: Codable, Hashable, Sendable {
    var id: UUID
    var tier: WalletTier
    var amount: MoneyAmount
    var maximumFee: MoneyAmount
    var memo: String
    var destinationDescriptorID: UUID
    var confirmationTargetSeconds: Int
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case tier
        case amount
        case maximumFee
        case memo
        case destinationDescriptorID
        case confirmationTargetSeconds
        case createdAt
    }

    init(
        id: UUID,
        tier: WalletTier,
        amount: MoneyAmount,
        maximumFee: MoneyAmount,
        memo: String,
        destinationDescriptorID: UUID,
        confirmationTargetSeconds: Int,
        createdAt: Date
    ) {
        self.id = id
        self.tier = tier
        self.amount = amount
        self.maximumFee = maximumFee
        self.memo = memo
        self.destinationDescriptorID = destinationDescriptorID
        self.confirmationTargetSeconds = confirmationTargetSeconds
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            tier: try container.decode(WalletTier.self, forKey: .tier),
            amount: try container.decode(MoneyAmount.self, forKey: .amount),
            maximumFee: try container.decodeIfPresent(MoneyAmount.self, forKey: .maximumFee)
                ?? MoneyAmount(minorUnits: 0, currencyCode: "NUMI"),
            memo: try container.decode(String.self, forKey: .memo),
            destinationDescriptorID: try container.decode(UUID.self, forKey: .destinationDescriptorID),
            confirmationTargetSeconds: try container.decodeIfPresent(Int.self, forKey: .confirmationTargetSeconds) ?? 30,
            createdAt: try container.decode(Date.self, forKey: .createdAt)
        )
    }
}

struct SpendAuthorization: Codable, Sendable {
    var draftID: UUID
    var approvedAt: Date
    var signature: Data
}

struct AppAttestArtifact: Codable, Sendable {
    var keyID: String
    var clientDataHash: Data
    var assertion: Data
    var issuedAt: Date
}

struct PaddedEnvelope: Codable, Sendable {
    var envelopeID: UUID
    var kind: EnvelopeKind
    var createdAt: Date
    var releaseSlot: Date
    var payload: Data
    var padding: Data
    var attestation: AppAttestArtifact?
}

struct CoinProtocolCapabilities: Codable, Sendable {
    var aliasDiscovery: Bool
    var pirStateUpdates: Bool
    var tagRatchets: Bool
    var dynamicFeeMarkets: Bool
    var relaySubmission: Bool

    static let base = CoinProtocolCapabilities(
        aliasDiscovery: false,
        pirStateUpdates: false,
        tagRatchets: false,
        dynamicFeeMarkets: false,
        relaySubmission: false
    )
}

struct RemoteServiceConfiguration: Sendable {
    var network: WalletNetwork
    var capabilities: CoinProtocolCapabilities
    var discoveryURL: URL?
    var pirURL: URL?
    var feeOracleURL: URL?
    var relayIngressURL: URL?
    var relayEgressURL: URL?
    var fixedEnvelopeSize: Int
    var pirEnvelopeSize: Int
    var batchWindow: TimeInterval

    var supportsAliasDiscovery: Bool { capabilities.aliasDiscovery }
    var supportsPIRStateUpdates: Bool { capabilities.pirStateUpdates }
    var supportsTagRatchets: Bool { capabilities.tagRatchets }
    var supportsDynamicFeeMarkets: Bool { capabilities.dynamicFeeMarkets }
    var supportsRelaySubmission: Bool { capabilities.relaySubmission }
    var supportsShieldedSpendPipeline: Bool {
        supportsRelaySubmission && supportsPIRStateUpdates && supportsTagRatchets
    }
    var supportsBackgroundPIRRefresh: Bool {
        supportsPIRStateUpdates && pirURL != nil
    }

    static func current(bundle: Bundle = .main) -> RemoteServiceConfiguration {
        RemoteServiceConfiguration(
            network: WalletNetwork(rawValue: bundle.object(forInfoDictionaryKey: "NUMI_NETWORK") as? String ?? "") ?? .mainnet,
            capabilities: CoinProtocolCapabilities(
                aliasDiscovery: bundle.bool(forInfoDictionaryKey: "NUMI_ENABLE_ALIAS_DISCOVERY", default: false),
                pirStateUpdates: bundle.bool(forInfoDictionaryKey: "NUMI_ENABLE_PIR_STATE_UPDATES", default: false),
                tagRatchets: bundle.bool(forInfoDictionaryKey: "NUMI_ENABLE_TAG_RATCHETS", default: false),
                dynamicFeeMarkets: bundle.bool(forInfoDictionaryKey: "NUMI_ENABLE_DYNAMIC_FEES", default: false),
                relaySubmission: bundle.bool(forInfoDictionaryKey: "NUMI_ENABLE_RELAY_SUBMISSION", default: false)
            ),
            discoveryURL: bundle.url(forInfoDictionaryKey: "NUMI_DISCOVERY_URL"),
            pirURL: bundle.url(forInfoDictionaryKey: "NUMI_PIR_URL"),
            feeOracleURL: bundle.url(forInfoDictionaryKey: "NUMI_FEE_ORACLE_URL"),
            relayIngressURL: bundle.url(forInfoDictionaryKey: "NUMI_RELAY_INGRESS_URL"),
            relayEgressURL: bundle.url(forInfoDictionaryKey: "NUMI_RELAY_EGRESS_URL"),
            fixedEnvelopeSize: bundle.integer(forInfoDictionaryKey: "NUMI_CONTROL_ENVELOPE_BYTES", default: 4096),
            pirEnvelopeSize: bundle.integer(forInfoDictionaryKey: "NUMI_PIR_ENVELOPE_BYTES", default: 1_048_576),
            batchWindow: bundle.double(forInfoDictionaryKey: "NUMI_BATCH_WINDOW_SECONDS", default: 30)
        )
    }
}

struct PairingInvitation: Codable, Sendable {
    var id: UUID
    var host: String
    var port: UInt16
    var bootstrapCode: String
    var transport: PairingTransport
    var verifyingKey: Data
    var issuedAt: Date
}

struct PairingAttestation: Codable, Sendable {
    var keyID: String
    var signature: Data
    var clientDataHash: Data?
}

struct PairingSessionTranscript: Codable, Sendable {
    var sessionID: UUID
    var invitationID: UUID
    var peerDeviceID: String
    var peerRole: DeviceRole
    var transport: PairingTransport
    var createdAt: Date
    var expiresAt: Date
    var challenge: Data
    var verifierPublicKey: Data
    var invitationSignature: Data
    var appAttestation: PairingAttestation?

    var fingerprint: String {
        let digest = SHA256.hash(data: challenge + verifierPublicKey + invitationSignature)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}

struct LocalProofJob: Hashable, Sendable {
    var id: UUID
    var label: String
    var witness: Data
    var rounds: Int
}

struct LocalProofArtifact: Codable, Sendable {
    var jobID: UUID
    var venue: String
    var duration: TimeInterval
    var digest: Data
    var completedAt: Date
}

struct WalletDashboardState: Sendable {
    var role: DeviceRole
    var isInitialized: Bool
    var isVaultUnlocked: Bool
    var isPeerPresent: Bool
    var dayBalance: String
    var vaultBalance: String?
    var dayDescriptorFingerprint: String?
    var vaultDescriptorFingerprint: String?
    var proofVenue: String
    var isPrivacyRedacted: Bool
    var captureDetected: Bool
    var pirStatus: String
    var lastPIRRefresh: String
    var payReadiness: String
    var lastFeeQuote: String
    var trackedTagRelationships: Int
    var trackedNotes: Int

    static func placeholder(role: DeviceRole) -> WalletDashboardState {
        WalletDashboardState(
            role: role,
            isInitialized: false,
            isVaultUnlocked: false,
            isPeerPresent: false,
            dayBalance: MoneyAmount.zero.formatted(),
            vaultBalance: nil,
            dayDescriptorFingerprint: nil,
            vaultDescriptorFingerprint: nil,
            proofVenue: "Not started",
            isPrivacyRedacted: false,
            captureDetected: false,
            pirStatus: "PIR state unavailable",
            lastPIRRefresh: "Never",
            payReadiness: "Not ready",
            lastFeeQuote: "No fee quote",
            trackedTagRelationships: 0,
            trackedNotes: 0
        )
    }
}
