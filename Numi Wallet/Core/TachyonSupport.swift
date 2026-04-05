import CryptoKit
import Foundation

enum TachyonSupport {
    static func digest(_ components: Data...) -> Data {
        digest(components)
    }

    static func digest(_ components: [Data]) -> Data {
        var hasher = SHA256()
        for component in components {
            hasher.update(data: component)
        }
        return Data(hasher.finalize())
    }

    static func digest<T: Encodable>(encodable value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return digest(try encoder.encode(value))
    }

    static func digest(string value: String) -> Data {
        digest(Data(value.utf8))
    }

    static func syntheticProofData(seed: Data, length: Int) -> Data {
        guard length > 0 else { return Data() }

        var material = Data()
        var counter: UInt32 = 0
        while material.count < length {
            let counterData = withUnsafeBytes(of: counter.littleEndian) { Data($0) }
            material.append(digest(seed, counterData))
            counter += 1
        }
        return material.prefix(length)
    }

    static func artifactDigest(
        jobDigest: Data,
        proofDigest: Data,
        transcriptDigest: Data,
        backend: TachyonProofBackendKind,
        compressionMode: TachyonProofCompressionMode
    ) -> Data {
        digest(
            jobDigest,
            proofDigest,
            transcriptDigest,
            Data(backend.rawValue.utf8),
            Data(compressionMode.rawValue.utf8)
        )
    }
}
