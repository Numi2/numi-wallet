import Foundation

enum PeerTrustLevel: String, Codable, Sendable {
    case attestedLocal
    case nearbyVerified
}

enum PeerProximityEvidence: String, Codable, Sendable {
    case authenticatedLocalChannel
    case nearbyInteraction

    var label: String {
        switch self {
        case .authenticatedLocalChannel:
            return "Authenticated Local Channel"
        case .nearbyInteraction:
            return "Nearby Interaction"
        }
    }
}

struct NearbyPeerVerification: Codable, Hashable, Sendable {
    let verifiedAt: Date
    let distanceMeters: Double
    let directionAvailable: Bool

    var distanceLabel: String {
        "\(distanceMeters.formatted(.number.precision(.fractionLength(1)))) m"
    }

    var label: String {
        directionAvailable ? "Nearby Interaction • \(distanceLabel) • Direction" : "Nearby Interaction • \(distanceLabel)"
    }
}

struct PeerTrustSession: Identifiable, Codable, Sendable {
    let id: UUID
    let peerName: String
    let peerKind: PeerKind
    let peerRole: DeviceRole
    let peerDeviceID: String
    let peerVerifyingKey: Data
    let invitationID: UUID
    let transcriptFingerprint: String
    let transport: PairingTransport
    let capabilities: [PeerSessionCapability]
    let proximityEvidence: PeerProximityEvidence
    let trustLevel: PeerTrustLevel
    let nearbyVerification: NearbyPeerVerification?
    let appAttested: Bool
    let establishedAt: Date
    let expiresAt: Date

    var isActive: Bool {
        expiresAt > Date()
    }

    var stateLabel: String {
        guard isActive else { return "Expired" }
        switch trustLevel {
        case .attestedLocal:
            return "Attested Local"
        case .nearbyVerified:
            return "Nearby Verified"
        }
    }

    var transportLabel: String {
        switch transport {
        case .nearbyInteraction:
            return "Nearby Interaction"
        case .networkFramework:
            return "Network.framework"
        }
    }

    var proximityLabel: String {
        switch proximityEvidence {
        case .authenticatedLocalChannel:
            return proximityEvidence.label
        case .nearbyInteraction:
            return nearbyVerification?.label ?? proximityEvidence.label
        }
    }
}
