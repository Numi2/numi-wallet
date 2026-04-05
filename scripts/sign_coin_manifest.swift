#!/usr/bin/env swift

import CryptoKit
import Foundation

private struct CoinManifestEnvelope: Codable {
    var format: String
    var signingKeyID: String
    var signingAlgorithm: String
    var payload: Data
    var signature: Data
}

private enum ManifestSigningError: LocalizedError {
    case usage
    case missingPrivateKey
    case invalidPrivateKey
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .usage:
            return "usage: sign_coin_manifest.swift <payload.json> <output.json>"
        case .missingPrivateKey:
            return "NUMI_MANIFEST_SIGNING_KEY_B64 is required."
        case .invalidPrivateKey:
            return "NUMI_MANIFEST_SIGNING_KEY_B64 is not a valid ML-DSA-87 integrity representation."
        case .invalidPayload:
            return "payload file must contain valid JSON."
        }
    }
}

private func main() throws {
    guard CommandLine.arguments.count == 3 else {
        throw ManifestSigningError.usage
    }

    let environment = ProcessInfo.processInfo.environment
    guard let privateKeyBase64 = environment["NUMI_MANIFEST_SIGNING_KEY_B64"],
          let privateKeyData = Data(base64Encoded: privateKeyBase64) else {
        throw ManifestSigningError.missingPrivateKey
    }

    let keyID = environment["NUMI_MANIFEST_SIGNING_KEY_ID"] ?? "numi.manifest.root.2026-04-05"
    let payloadURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let payloadData = try Data(contentsOf: payloadURL)

    guard (try? JSONSerialization.jsonObject(with: payloadData)) != nil else {
        throw ManifestSigningError.invalidPayload
    }

    let privateKey: MLDSA87.PrivateKey
    do {
        privateKey = try MLDSA87.PrivateKey(integrityCheckedRepresentation: privateKeyData)
    } catch {
        throw ManifestSigningError.invalidPrivateKey
    }

    let signature = try privateKey.signature(for: payloadData)
    let manifest = CoinManifestEnvelope(
        format: "numi.coin-manifest.v1",
        signingKeyID: keyID,
        signingAlgorithm: "ML-DSA-87",
        payload: payloadData,
        signature: signature
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: outputURL, options: .atomic)
}

do {
    try main()
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
