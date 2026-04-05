import CryptoKit
import Foundation

actor DynamicFeeEngine {
    private let configuration: RemoteServiceConfiguration
    private let feeOracle: FeeOracleClient

    init(configuration: RemoteServiceConfiguration, feeOracle: FeeOracleClient) {
        self.configuration = configuration
        self.feeOracle = feeOracle
    }

    func prepareAuthorization(
        draft: SpendDraft,
        source: ShieldedSpendSource
    ) async throws -> DynamicFeeAuthorizationBundle {
        if !configuration.supportsDynamicFeeMarkets {
            return try makeStaticAuthorization(draft: draft, source: source)
        }

        let quote = try await feeOracle.fetchQuote(
            maximumFee: draft.maximumFee,
            confirmationTargetSeconds: draft.confirmationTargetSeconds
        )
        guard quote.recommendedFee.minorUnits <= draft.maximumFee.minorUnits else {
            throw WalletError.insufficientFunds
        }

        let hotkey = try MLDSA65.PrivateKey()
        let commitmentSalt = randomData(length: 32)
        let commitment = Data(
            SHA256.hash(
                data: source.nullifier
                    + commitmentSalt
                    + encodeUInt64(UInt64(draft.maximumFee.minorUnits))
                    + hotkey.publicKey.rawRepresentation
            )
        )
        let settlementDigest = Data(
            SHA256.hash(
                data: commitment
                    + encodeUInt64(quote.marketRatePerWeight)
                    + encodeUInt64(UInt64(quote.recommendedFee.minorUnits))
            )
        )
        let witnessDigest = Data(SHA256.hash(data: settlementDigest + Data("numi.fee.zk.v1".utf8)))
        let authorizationSignature = try hotkey.signature(for: settlementDigest)

        return DynamicFeeAuthorizationBundle(
            quote: quote,
            commitmentProof: FeeCommitmentProof(
                algorithm: "NUMI-FEE-COMMITMENT-V1",
                commitment: commitment,
                witnessDigest: witnessDigest,
                maximumFee: draft.maximumFee,
                generatedAt: Date()
            ),
            hotkey: AuthorizedFeeHotkey(
                algorithm: "ML-DSA-65",
                publicKey: hotkey.publicKey.rawRepresentation,
                authorizationSignature: authorizationSignature,
                expiresAt: min(quote.expiresAt, Date().addingTimeInterval(120))
            ),
            settlement: FeeSettlementAuthorization(
                quotedFee: quote.recommendedFee,
                maximumFee: draft.maximumFee,
                refundAmount: MoneyAmount(
                    minorUnits: max(0, draft.maximumFee.minorUnits - quote.recommendedFee.minorUnits),
                    currencyCode: draft.maximumFee.currencyCode
                ),
                marketRatePerWeight: quote.marketRatePerWeight,
                settlementDigest: settlementDigest,
                authorizedAt: Date()
            )
        )
    }

    private func makeStaticAuthorization(
        draft: SpendDraft,
        source: ShieldedSpendSource
    ) throws -> DynamicFeeAuthorizationBundle {
        let hotkey = try MLDSA65.PrivateKey()
        let settlementDigest = Data(
            SHA256.hash(
                data: source.nullifier
                    + encodeUInt64(UInt64(draft.maximumFee.minorUnits))
                    + hotkey.publicKey.rawRepresentation
            )
        )
        return DynamicFeeAuthorizationBundle(
            quote: FeeQuote(
                quoteID: UUID(),
                marketRatePerWeight: 0,
                recommendedFee: draft.maximumFee,
                expiresAt: Date().addingTimeInterval(120),
                fetchedAt: Date()
            ),
            commitmentProof: FeeCommitmentProof(
                algorithm: "NUMI-FEE-STATIC-V1",
                commitment: settlementDigest,
                witnessDigest: Data(SHA256.hash(data: settlementDigest + Data("numi.fee.static".utf8))),
                maximumFee: draft.maximumFee,
                generatedAt: Date()
            ),
            hotkey: AuthorizedFeeHotkey(
                algorithm: "ML-DSA-65",
                publicKey: hotkey.publicKey.rawRepresentation,
                authorizationSignature: try hotkey.signature(for: settlementDigest),
                expiresAt: Date().addingTimeInterval(120)
            ),
            settlement: FeeSettlementAuthorization(
                quotedFee: draft.maximumFee,
                maximumFee: draft.maximumFee,
                refundAmount: MoneyAmount(minorUnits: 0, currencyCode: draft.maximumFee.currencyCode),
                marketRatePerWeight: 0,
                settlementDigest: settlementDigest,
                authorizedAt: Date()
            )
        )
    }

    private func encodeUInt64(_ value: UInt64) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }

    private func randomData(length: Int) -> Data {
        Data((0..<length).map { _ in UInt8.random(in: .min ... .max) })
    }
}
