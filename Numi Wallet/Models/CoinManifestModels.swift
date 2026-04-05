import Foundation

struct CoinManifestEnvelope: Codable, Sendable {
    static let formatIdentifier = "numi.coin-manifest.v1"
    static let requiredSigningAlgorithm = "ML-DSA-87"

    var format: String
    var signingKeyID: String
    var signingAlgorithm: String
    var payload: Data
    var signature: Data
}

struct CoinManifestPayload: Codable, Sendable {
    static let formatIdentifier = "numi.coin-profile.v1"

    var format: String
    var coinID: String
    var displayName: String
    var assetCode: String
    var network: WalletNetwork
    var capabilities: CoinProtocolCapabilities
    var services: CoinServiceEndpoints
    var transport: CoinTransportConfiguration
}

struct CoinServiceEndpoints: Codable, Sendable {
    var discovery: URL?
    var pir: URL?
    var feeOracle: URL?
    var relayIngress: URL?
    var relayEgress: URL?
}

struct CoinTransportConfiguration: Codable, Sendable {
    var controlEnvelopeBytes: Int
    var pirEnvelopeBytes: Int
    var batchWindowSeconds: TimeInterval
}

struct CoinManifestTrustRoot: Sendable {
    let keyID: String
    let publicKey: Data

    static let current = CoinManifestTrustRoot(
        keyID: "numi.manifest.root.2026-04-05",
        publicKey: currentPublicKey()
    )

    static func resolve(keyID: String) throws -> CoinManifestTrustRoot {
        guard keyID == current.keyID else {
            throw CoinManifestError.unknownSigningKey(keyID)
        }
        return current
    }

    private static func currentPublicKey() -> Data {
        let encoded =
            "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"
        guard let data = Data(base64Encoded: encoded) else {
            preconditionFailure("Pinned manifest public key is invalid.")
        }
        return data
    }
}

struct VerifiedCoinManifest: Sendable {
    var payload: CoinManifestPayload
    var configuration: RemoteServiceConfiguration
}

enum CoinManifestError: LocalizedError, Sendable {
    case missingResource(String)
    case unreadableResource(String)
    case invalidEnvelope(String)
    case unsupportedEnvelopeFormat(String)
    case unsupportedPayloadFormat(String)
    case unsupportedSigningAlgorithm(String)
    case unknownSigningKey(String)
    case invalidSignature
    case invalidPayload(String)
    case invalidTransportPolicy(String)
    case invalidServiceTopology(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Bundled coin manifest \(name) is missing."
        case .unreadableResource(let detail):
            return "Bundled coin manifest could not be read: \(detail)"
        case .invalidEnvelope(let detail):
            return "Bundled coin manifest envelope is invalid: \(detail)"
        case .unsupportedEnvelopeFormat(let format):
            return "Bundled coin manifest format \(format) is not recognized."
        case .unsupportedPayloadFormat(let format):
            return "Coin profile format \(format) is not recognized."
        case .unsupportedSigningAlgorithm(let algorithm):
            return "Bundled coin manifest uses unsupported signing algorithm \(algorithm)."
        case .unknownSigningKey(let keyID):
            return "Bundled coin manifest references unknown signing key \(keyID)."
        case .invalidSignature:
            return "Bundled coin manifest signature verification failed."
        case .invalidPayload(let detail):
            return "Bundled coin profile is invalid: \(detail)"
        case .invalidTransportPolicy(let detail):
            return "Bundled coin transport policy is invalid: \(detail)"
        case .invalidServiceTopology(let detail):
            return "Bundled coin service topology is invalid: \(detail)"
        }
    }
}
