import CryptoKit
import Foundation

struct CoinManifestLoader {
    private let decoder = JSONDecoder()

    func load(from bundle: Bundle = .main, resourceName: String = "NumiCoinManifest") throws -> VerifiedCoinManifest {
        guard let resourceURL = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CoinManifestError.missingResource("\(resourceName).json")
        }

        let envelopeData: Data
        do {
            envelopeData = try Data(contentsOf: resourceURL)
        } catch {
            throw CoinManifestError.unreadableResource(error.localizedDescription)
        }

        let envelope: CoinManifestEnvelope
        do {
            envelope = try decoder.decode(CoinManifestEnvelope.self, from: envelopeData)
        } catch {
            throw CoinManifestError.invalidEnvelope(error.localizedDescription)
        }

        guard envelope.format == CoinManifestEnvelope.formatIdentifier else {
            throw CoinManifestError.unsupportedEnvelopeFormat(envelope.format)
        }
        guard envelope.signingAlgorithm == CoinManifestEnvelope.requiredSigningAlgorithm else {
            throw CoinManifestError.unsupportedSigningAlgorithm(envelope.signingAlgorithm)
        }

        let trustRoot = try CoinManifestTrustRoot.resolve(keyID: envelope.signingKeyID)
        let publicKey = try MLDSA87.PublicKey(rawRepresentation: trustRoot.publicKey)
        guard publicKey.isValidSignature(envelope.signature, for: envelope.payload) else {
            throw CoinManifestError.invalidSignature
        }

        let payload: CoinManifestPayload
        do {
            payload = try decoder.decode(CoinManifestPayload.self, from: envelope.payload)
        } catch {
            throw CoinManifestError.invalidPayload(error.localizedDescription)
        }

        guard payload.format == CoinManifestPayload.formatIdentifier else {
            throw CoinManifestError.unsupportedPayloadFormat(payload.format)
        }

        return VerifiedCoinManifest(
            payload: payload,
            configuration: try RemoteServiceConfiguration(validatedManifest: payload)
        )
    }
}
