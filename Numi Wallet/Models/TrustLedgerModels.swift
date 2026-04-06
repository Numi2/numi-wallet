import Foundation

enum TrustLedgerEventKind: String, Codable, Sendable {
    case peerSessionEstablished
    case peerSessionSealed
    case peerSessionExpired
    case peerRevoked
    case recoveryEnvelopePrepared
    case recoveryEnvelopeConsumed

    var title: String {
        switch self {
        case .peerSessionEstablished:
            return "Peer Trusted"
        case .peerSessionSealed:
            return "Trust Session Sealed"
        case .peerSessionExpired:
            return "Trust Session Expired"
        case .peerRevoked:
            return "Peer Revoked"
        case .recoveryEnvelopePrepared:
            return "Recovery Transfer Prepared"
        case .recoveryEnvelopeConsumed:
            return "Recovery Transfer Consumed"
        }
    }

    var systemImage: String {
        switch self {
        case .peerSessionEstablished:
            return "checkmark.seal.fill"
        case .peerSessionSealed:
            return "lock.fill"
        case .peerSessionExpired:
            return "clock.badge.exclamationmark.fill"
        case .peerRevoked:
            return "hand.raised.fill"
        case .recoveryEnvelopePrepared:
            return "square.and.arrow.up.fill"
        case .recoveryEnvelopeConsumed:
            return "square.and.arrow.down.fill"
        }
    }
}

enum TrustLedgerTransferAction: Equatable, Sendable {
    case prepared
    case consumed
}

struct TrustedPeerRecord: Identifiable, Codable, Sendable {
    let id: String
    var peerName: String
    var peerKind: PeerKind
    var peerRole: DeviceRole
    var peerDeviceID: String
    var lastTranscriptFingerprint: String
    var lastTrustLevel: PeerTrustLevel
    var lastTransport: PairingTransport
    var capabilities: [PeerSessionCapability]
    var lastVerifiedProximity: PeerProximityEvidence
    var nearbyVerification: NearbyPeerVerification?
    var appAttested: Bool
    var lastEstablishedAt: Date
    var lastExpiresAt: Date
    var lastSealedAt: Date?
    var revokedAt: Date?

    var isCurrentTrust: Bool {
        guard revokedAt == nil else { return false }
        guard lastExpiresAt > Date() else { return false }
        guard let lastSealedAt else { return true }
        return lastSealedAt < lastEstablishedAt
    }

    var statusLabel: String {
        if revokedAt != nil {
            return "Revoked"
        }
        if isCurrentTrust {
            switch lastTrustLevel {
            case .attestedLocal:
                return "Attested Local"
            case .nearbyVerified:
                return "Nearby Verified"
            }
        }
        if lastExpiresAt <= Date() {
            return "Expired"
        }
        return "Sealed"
    }

    var proximityLabel: String {
        switch lastVerifiedProximity {
        case .authenticatedLocalChannel:
            return lastVerifiedProximity.label
        case .nearbyInteraction:
            return nearbyVerification?.label ?? lastVerifiedProximity.label
        }
    }
}

struct TrustLedgerEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let kind: TrustLedgerEventKind
    let localRole: DeviceRole
    let peerName: String?
    let peerRole: DeviceRole?
    let fingerprint: String?
    let summary: String
    let detail: String
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        kind: TrustLedgerEventKind,
        localRole: DeviceRole,
        peerName: String? = nil,
        peerRole: DeviceRole? = nil,
        fingerprint: String? = nil,
        summary: String,
        detail: String,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.localRole = localRole
        self.peerName = peerName
        self.peerRole = peerRole
        self.fingerprint = fingerprint
        self.summary = summary
        self.detail = detail
        self.occurredAt = occurredAt
    }
}

struct TrustLedgerSnapshot: Codable, Sendable {
    var peers: [TrustedPeerRecord]
    var events: [TrustLedgerEvent]

    static let empty = TrustLedgerSnapshot(peers: [], events: [])

    var activePeerCount: Int {
        peers.filter(\.isCurrentTrust).count
    }

    var recentTransferCount: Int {
        events.filter {
            $0.kind == .recoveryEnvelopePrepared || $0.kind == .recoveryEnvelopeConsumed
        }.count
    }

    var lastEventAt: Date? {
        events.first?.occurredAt
    }

    mutating func upsert(peer record: TrustedPeerRecord) {
        if let index = peers.firstIndex(where: { $0.id == record.id }) {
            peers[index] = record
        } else {
            peers.insert(record, at: 0)
        }
        peers.sort { $0.lastEstablishedAt > $1.lastEstablishedAt }
        peers = Array(peers.prefix(8))
    }

    mutating func updatePeer(deviceID: String, _ update: (inout TrustedPeerRecord) -> Void) {
        guard let index = peers.firstIndex(where: { $0.peerDeviceID == deviceID }) else { return }
        update(&peers[index])
        peers.sort { $0.lastEstablishedAt > $1.lastEstablishedAt }
    }

    mutating func prepend(event: TrustLedgerEvent, maxEvents: Int = 14) {
        events.insert(event, at: 0)
        events = Array(events.prefix(maxEvents))
    }
}
