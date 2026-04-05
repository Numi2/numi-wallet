import Foundation

enum RecoveryTransferPayload: Sendable {
    case peerShare(RecoveryShareEnvelope)
    case authorityBundle([RecoveryShareEnvelope])
}

extension RecoveryTransferPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case share
        case shares
    }

    private enum Kind: String, Codable {
        case peerShare
        case authorityBundle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .peerShare:
            self = .peerShare(try container.decode(RecoveryShareEnvelope.self, forKey: .share))
        case .authorityBundle:
            self = .authorityBundle(try container.decode([RecoveryShareEnvelope].self, forKey: .shares))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .peerShare(let share):
            try container.encode(Kind.peerShare, forKey: .kind)
            try container.encode(share, forKey: .share)
        case .authorityBundle(let shares):
            try container.encode(Kind.authorityBundle, forKey: .kind)
            try container.encode(shares, forKey: .shares)
        }
    }
}

struct UnsignedRecoveryTransferEnvelope: Codable, Sendable {
    let id: UUID
    let senderRole: DeviceRole
    let senderDeviceID: String
    let senderVerifyingKey: Data
    let recipientRole: DeviceRole
    let createdAt: Date
    let expiresAt: Date
    let trustSessionFingerprint: String?
    let payload: RecoveryTransferPayload
}

struct RecoveryTransferEnvelope: Codable, Identifiable, Sendable {
    let id: UUID
    let senderRole: DeviceRole
    let senderDeviceID: String
    let senderVerifyingKey: Data
    let recipientRole: DeviceRole
    let createdAt: Date
    let expiresAt: Date
    let trustSessionFingerprint: String?
    let payload: RecoveryTransferPayload
    let signature: Data

    var isExpired: Bool {
        expiresAt < Date()
    }

    func unsignedEnvelope() -> UnsignedRecoveryTransferEnvelope {
        UnsignedRecoveryTransferEnvelope(
            id: id,
            senderRole: senderRole,
            senderDeviceID: senderDeviceID,
            senderVerifyingKey: senderVerifyingKey,
            recipientRole: recipientRole,
            createdAt: createdAt,
            expiresAt: expiresAt,
            trustSessionFingerprint: trustSessionFingerprint,
            payload: payload
        )
    }
}
