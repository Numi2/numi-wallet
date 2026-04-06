import CryptoKit
import Foundation

enum PeerSessionCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case peerPresence
    case recoveryTransfer
    case descriptorExchange
    case recoveryApproval
    case diagnosticsConsole

    static func defaults(for role: DeviceRole) -> [PeerSessionCapability] {
        let capabilities: [PeerSessionCapability] = switch role {
        case .authorityPhone:
            [.peerPresence, .recoveryTransfer, .descriptorExchange]
        case .recoveryPad:
            [.peerPresence, .recoveryTransfer, .recoveryApproval]
        case .recoveryMac:
            [.peerPresence, .recoveryTransfer, .recoveryApproval, .diagnosticsConsole]
        }
        return canonicalize(capabilities)
    }

    static func canonicalize<S: Sequence>(_ capabilities: S) -> [PeerSessionCapability] where S.Element == PeerSessionCapability {
        Array(Set(capabilities)).sorted { $0.rawValue < $1.rawValue }
    }

    var label: String {
        switch self {
        case .peerPresence:
            return "Peer Presence"
        case .recoveryTransfer:
            return "Recovery Transfer"
        case .descriptorExchange:
            return "Descriptor Exchange"
        case .recoveryApproval:
            return "Recovery Approval"
        case .diagnosticsConsole:
            return "Diagnostics Console"
        }
    }
}

extension DeviceRole {
    var peerKind: PeerKind? {
        switch self {
        case .authorityPhone:
            return nil
        case .recoveryPad:
            return .pad
        case .recoveryMac:
            return .mac
        }
    }
}

extension PairingInvitation {
    var fingerprint: String {
        let payload = [
            id.uuidString.lowercased(),
            deviceID,
            deviceRole.rawValue,
            bootstrapCode,
            supportsNearbyInteraction ? "1" : "0",
            verifyingKey.base64EncodedString(),
            sessionBootstrapPublicKey.base64EncodedString()
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    var serviceName: String {
        "numi-\(deviceRole.rawValue)-\(bootstrapCode)"
    }
}

struct DiscoveredLocalPeerEndpoint: Identifiable, Hashable, Sendable {
    let id: String
    let serviceName: String
    let advertisedRole: DeviceRole?
    let endpointLabel: String
    let discoveredAt: Date
}

struct LocalPeerTransportSnapshot: Sendable {
    var invitation: PairingInvitation?
    var isAdvertising: Bool
    var endpointLabel: String
    var discoveredPeers: [DiscoveredLocalPeerEndpoint]
    var availableRemoteRoles: [DeviceRole]
    var activeSessionCount: Int
    var pendingIncomingTransferCount: Int

    static let inactive = LocalPeerTransportSnapshot(
        invitation: nil,
        isAdvertising: false,
        endpointLabel: "Local pairing idle",
        discoveredPeers: [],
        availableRemoteRoles: [],
        activeSessionCount: 0,
        pendingIncomingTransferCount: 0
    )
}

struct LocalPairingCiphertext: Codable, Sendable {
    let encapsulatedKey: Data
    let ciphertext: Data
}

struct UnsignedLocalPairingHello: Codable, Sendable {
    let invitation: PairingInvitation
    let invitationSignature: Data
    let peerName: String
    let challenge: Data
    let appAttestation: PairingAttestation?
    let sentAt: Date
}

struct LocalPairingHello: Codable, Sendable {
    let invitation: PairingInvitation
    let invitationSignature: Data
    let peerName: String
    let challenge: Data
    let appAttestation: PairingAttestation?
    let sentAt: Date
    let signature: Data

    func unsigned() -> UnsignedLocalPairingHello {
        UnsignedLocalPairingHello(
            invitation: invitation,
            invitationSignature: invitationSignature,
            peerName: peerName,
            challenge: challenge,
            appAttestation: appAttestation,
            sentAt: sentAt
        )
    }
}

struct UnsignedLocalPairingHelloAck: Codable, Sendable {
    let responderInvitation: PairingInvitation
    let responderInvitationSignature: Data
    let responderPeerName: String
    let sessionID: UUID
    let establishedAt: Date
    let expiresAt: Date
    let challengeDigest: Data
    let sessionBindingDigest: Data
    let encryptedSessionSecret: LocalPairingCiphertext
    let appAttestation: PairingAttestation?
}

struct LocalPairingHelloAck: Codable, Sendable {
    let responderInvitation: PairingInvitation
    let responderInvitationSignature: Data
    let responderPeerName: String
    let sessionID: UUID
    let establishedAt: Date
    let expiresAt: Date
    let challengeDigest: Data
    let sessionBindingDigest: Data
    let encryptedSessionSecret: LocalPairingCiphertext
    let appAttestation: PairingAttestation?
    let signature: Data

    func unsigned() -> UnsignedLocalPairingHelloAck {
        UnsignedLocalPairingHelloAck(
            responderInvitation: responderInvitation,
            responderInvitationSignature: responderInvitationSignature,
            responderPeerName: responderPeerName,
            sessionID: sessionID,
            establishedAt: establishedAt,
            expiresAt: expiresAt,
            challengeDigest: challengeDigest,
            sessionBindingDigest: sessionBindingDigest,
            encryptedSessionSecret: encryptedSessionSecret,
            appAttestation: appAttestation
        )
    }
}

struct UnsignedLocalPairingSessionSeal: Codable, Sendable {
    let sessionID: UUID
    let sessionBindingDigest: Data
    let sessionSecretDigest: Data
    let confirmedAt: Date
}

struct LocalPairingSessionSeal: Codable, Sendable {
    let sessionID: UUID
    let sessionBindingDigest: Data
    let sessionSecretDigest: Data
    let confirmedAt: Date
    let signature: Data

    func unsigned() -> UnsignedLocalPairingSessionSeal {
        UnsignedLocalPairingSessionSeal(
            sessionID: sessionID,
            sessionBindingDigest: sessionBindingDigest,
            sessionSecretDigest: sessionSecretDigest,
            confirmedAt: confirmedAt
        )
    }
}

struct AuthenticatedLocalPeerSession: Identifiable, Sendable {
    let id: UUID
    let localInvitationID: UUID
    let remoteInvitationID: UUID
    let localDeviceID: String
    let remoteDeviceID: String
    let localRole: DeviceRole
    let remoteRole: DeviceRole
    let remotePeerName: String
    let remoteVerifyingKey: Data
    let transport: PairingTransport
    let supportsNearbyInteraction: Bool
    let remoteCapabilities: [PeerSessionCapability]
    let transcriptFingerprint: String
    let sessionBindingDigest: Data
    let sessionSecretDigest: Data
    let localAppAttested: Bool
    let remoteAppAttested: Bool
    let establishedAt: Date
    let expiresAt: Date
    var proximityEvidence: PeerProximityEvidence
    var trustLevel: PeerTrustLevel
    var nearbyVerification: NearbyPeerVerification?

    var remotePeerKind: PeerKind? {
        remoteRole.peerKind
    }

    var isActive: Bool {
        establishedAt <= Date() && expiresAt > Date()
    }

    func upgradingNearbyVerification(_ verification: NearbyPeerVerification) -> AuthenticatedLocalPeerSession {
        var upgraded = self
        upgraded.proximityEvidence = .nearbyInteraction
        upgraded.trustLevel = .nearbyVerified
        upgraded.nearbyVerification = verification
        return upgraded
    }
}

struct LocalNearbyInteractionTokenPacket: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let senderRole: DeviceRole
    let senderDeviceID: String
    let sentAt: Date
    let sealedTokenData: Data
}

struct LocalRecoveryTransferPacket: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let senderRole: DeviceRole
    let senderDeviceID: String
    let recipientRole: DeviceRole
    let documentID: UUID
    let documentDigest: Data
    let sentAt: Date
    let sealedPayload: Data
}

struct PendingLocalRecoveryTransfer: Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let peerName: String
    let senderRole: DeviceRole
    let senderDeviceID: String
    let recipientRole: DeviceRole
    let document: RecoveryTransferDocument
    let receivedAt: Date
}

struct LocalRecoveryTransferReceipt: Sendable {
    let sessionID: UUID
    let remotePeerName: String
    let remoteRole: DeviceRole
    let documentID: UUID
    let sentAt: Date
}
