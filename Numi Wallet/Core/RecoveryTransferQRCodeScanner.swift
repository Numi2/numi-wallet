import CoreImage
import Foundation

struct RecoveryTransferQRCodeScanner: Sendable {
    func assembleDocument(from assets: [RecoveryTransferImportAsset]) throws -> RecoveryTransferDocument {
        let chunks = try assets.map { asset in
            let payload = try extractPayload(from: asset)
            return try RecoveryTransferQRCodeCodec.decodeChunk(from: payload)
        }
        return try RecoveryTransferQRCodeCodec.assembleDocument(from: chunks)
    }

    private func extractPayload(from asset: RecoveryTransferImportAsset) throws -> String {
        guard let image = CIImage(data: asset.data) else {
            throw WalletError.invalidRecoveryTransferQRCode
        }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        guard let feature = detector?.features(in: image).first as? CIQRCodeFeature,
              let payload = feature.messageString,
              !payload.isEmpty else {
            throw WalletError.invalidRecoveryTransferQRCode
        }
        return payload
    }
}
