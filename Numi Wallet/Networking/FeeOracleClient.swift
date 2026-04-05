import Foundation

actor FeeOracleClient {
    private let configuration: RemoteServiceConfiguration
    private let codec: EnvelopeCodec
    private let appAttest: AppAttestProvider
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: RemoteServiceConfiguration,
        codec: EnvelopeCodec,
        appAttest: AppAttestProvider,
        session: URLSession = PrivacyPreservingURLSessionFactory.make(timeout: 15)
    ) {
        self.configuration = configuration
        self.codec = codec
        self.appAttest = appAttest
        self.session = session
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchQuote(maximumFee: MoneyAmount, confirmationTargetSeconds: Int) async throws -> FeeQuote {
        guard configuration.supportsDynamicFeeMarkets else {
            throw WalletError.featureUnavailable("Dynamic fee markets")
        }
        guard let baseURL = configuration.feeOracleURL else {
            throw WalletError.misconfiguredService("Fee oracle")
        }

        let requestBody = FeeQuoteRequest(
            maximumFee: maximumFee,
            confirmationTargetSeconds: confirmationTargetSeconds
        )
        let body = try encoder.encode(requestBody)
        guard let attestation = try await appAttest.assertion(for: body) else {
            throw WalletError.appAttestUnavailable
        }
        let envelope = try codec.makeEnvelope(
            kind: .feeQuote,
            payload: body,
            attestation: attestation
        )

        var request = URLRequest(url: baseURL.appending(path: "quote"))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = session.configuration.timeoutIntervalForRequest
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try encoder.encode(envelope)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200..<300).contains(statusCode) else {
            throw WalletError.remoteServiceUnavailable("Fee oracle")
        }

        do {
            return try decoder.decode(FeeQuoteResponse.self, from: data).quote
        } catch {
            throw WalletError.invalidRemoteResponse("Fee oracle")
        }
    }
}
