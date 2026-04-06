import CryptoKit
import Foundation

enum RecoveryTransferPayload: Sendable {
    case peerShare(RecoveryShareEnvelope)
    case authorityBundle([RecoveryShareEnvelope])

    var fileStem: String {
        switch self {
        case .peerShare(let share):
            return "peer-share-\(share.peerKind.rawValue)"
        case .authorityBundle:
            return "authority-recovery"
        }
    }
}

struct RecoveryTransferDocument: Codable, Identifiable, Sendable {
    static let formatIdentifier = "numi.recovery-transfer"
    static let fileExtension = "numi-transfer"

    let id: UUID
    let formatIdentifier: String
    let createdAt: Date
    let envelope: RecoveryTransferEnvelope
    let envelopeDigest: Data

    init(
        id: UUID,
        formatIdentifier: String = Self.formatIdentifier,
        createdAt: Date,
        envelope: RecoveryTransferEnvelope,
        envelopeDigest: Data
    ) {
        self.id = id
        self.formatIdentifier = formatIdentifier
        self.createdAt = createdAt
        self.envelope = envelope
        self.envelopeDigest = envelopeDigest
    }

    static func make(from envelope: RecoveryTransferEnvelope) throws -> RecoveryTransferDocument {
        RecoveryTransferDocument(
            id: envelope.id,
            createdAt: Date(),
            envelope: envelope,
            envelopeDigest: Data(SHA256.hash(data: try canonicalEnvelopeData(for: envelope)))
        )
    }

    static func decode(from data: Data) throws -> RecoveryTransferDocument {
        let document = try canonicalDecoder().decode(RecoveryTransferDocument.self, from: data)
        try document.validate()
        return document
    }

    static func encode(_ document: RecoveryTransferDocument) throws -> Data {
        try document.validate()
        return try canonicalEncoder().encode(document)
    }

    var recommendedFilename: String {
        "numi-\(envelope.payload.fileStem)-\(id.uuidString.prefix(8)).\(Self.fileExtension)"
    }

    func validate() throws {
        guard formatIdentifier == Self.formatIdentifier,
              id == envelope.id else {
            throw WalletError.invalidRecoveryTransferDocument
        }
        let expectedDigest = Data(SHA256.hash(data: try Self.canonicalEnvelopeData(for: envelope)))
        guard expectedDigest == envelopeDigest else {
            throw WalletError.invalidRecoveryTransferDocument
        }
    }

    private static func canonicalEnvelopeData(for envelope: RecoveryTransferEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    private static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func canonicalDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}

struct RecoveryTransferQRCodeChunk: Codable, Identifiable, Sendable {
    let id: UUID
    let documentID: UUID
    let documentDigest: Data
    let index: Int
    let totalCount: Int
    let payloadFragment: String

    var label: String {
        "Chunk \(index + 1) / \(totalCount)"
    }

    func qrPayloadString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}

enum RecoveryTransferQRCodeCodec {
    static func makeChunks(
        for document: RecoveryTransferDocument,
        maxFragmentLength: Int = 280
    ) throws -> [RecoveryTransferQRCodeChunk] {
        guard maxFragmentLength >= 64 else {
            throw WalletError.invalidRecoveryTransferQRCode
        }

        let documentData = try RecoveryTransferDocument.encode(document)
        let documentDigest = Data(SHA256.hash(data: documentData))
        let payload = documentData.base64EncodedString()
        let fragments = stride(from: 0, to: payload.count, by: maxFragmentLength).map { start in
            let lowerBound = payload.index(payload.startIndex, offsetBy: start)
            let upperBound = payload.index(lowerBound, offsetBy: min(maxFragmentLength, payload.distance(from: lowerBound, to: payload.endIndex)))
            return String(payload[lowerBound..<upperBound])
        }

        guard !fragments.isEmpty else {
            throw WalletError.invalidRecoveryTransferQRCode
        }

        return fragments.enumerated().map { index, fragment in
            RecoveryTransferQRCodeChunk(
                id: UUID(),
                documentID: document.id,
                documentDigest: documentDigest,
                index: index,
                totalCount: fragments.count,
                payloadFragment: fragment
            )
        }
    }

    static func decodeChunk(from string: String) throws -> RecoveryTransferQRCodeChunk {
        let decoder = JSONDecoder()
        let chunk = try decoder.decode(RecoveryTransferQRCodeChunk.self, from: Data(string.utf8))
        try validate(chunk)
        return chunk
    }

    static func assembleDocument(from chunks: [RecoveryTransferQRCodeChunk]) throws -> RecoveryTransferDocument {
        guard let first = chunks.first else {
            throw WalletError.invalidRecoveryTransferQRCode
        }

        let expectedIndexes = Set(0..<first.totalCount)
        let actualIndexes = Set(chunks.map(\.index))
        guard chunks.count == first.totalCount,
              actualIndexes == expectedIndexes,
              chunks.allSatisfy({
                  $0.documentID == first.documentID &&
                  $0.documentDigest == first.documentDigest &&
                  $0.totalCount == first.totalCount
              })
        else {
            throw WalletError.invalidRecoveryTransferQRCode
        }

        let payload = chunks
            .sorted { $0.index < $1.index }
            .map(\.payloadFragment)
            .joined()
        guard let data = Data(base64Encoded: payload) else {
            throw WalletError.invalidRecoveryTransferQRCode
        }
        let document = try RecoveryTransferDocument.decode(from: data)
        let documentDigest = Data(SHA256.hash(data: data))
        guard document.id == first.documentID,
              documentDigest == first.documentDigest else {
            throw WalletError.invalidRecoveryTransferQRCode
        }
        return document
    }

    private static func validate(_ chunk: RecoveryTransferQRCodeChunk) throws {
        guard chunk.totalCount > 0,
              chunk.index >= 0,
              chunk.index < chunk.totalCount,
              !chunk.payloadFragment.isEmpty else {
            throw WalletError.invalidRecoveryTransferQRCode
        }
    }
}

struct StagedRecoveryTransfer: Identifiable, Sendable {
    let document: RecoveryTransferDocument
    let fileURL: URL?
    let qrChunks: [RecoveryTransferQRCodeChunk]

    var id: UUID { document.id }
}

struct RecoveryTransferImportAsset: Sendable {
    let data: Data
    let sourceLabel: String
}

struct PendingRecoveryTransferPreview: Identifiable, Sendable {
    let id: UUID
    let sourceLabel: String
    let senderRole: DeviceRole
    let recipientRole: DeviceRole
    let kindLabel: String
    let recommendation: String
    let expiresAt: Date
    let transcriptFingerprint: String?

    var expiresLabel: String {
        expiresAt.formatted(date: .omitted, time: .shortened)
    }
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

    func approvalPreview(sourceLabel: String) -> PendingRecoveryTransferPreview {
        let kindLabel: String
        let recommendation: String
        switch payload {
        case .peerShare(let share):
            kindLabel = "Peer Share • \(share.peerName)"
            recommendation = "Approve only if this local session still matches the intended peer custody action."
        case .authorityBundle(let shares):
            kindLabel = "Authority Bundle • \(shares.count) fragment\(shares.count == 1 ? "" : "s")"
            recommendation = "Approve only if this device is the intended authority re-enrollment target for the current local session."
        }

        return PendingRecoveryTransferPreview(
            id: id,
            sourceLabel: sourceLabel,
            senderRole: senderRole,
            recipientRole: recipientRole,
            kindLabel: kindLabel,
            recommendation: recommendation,
            expiresAt: expiresAt,
            transcriptFingerprint: trustSessionFingerprint
        )
    }
}
