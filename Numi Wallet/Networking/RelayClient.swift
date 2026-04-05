import Foundation

actor RelayClient {
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
        session: URLSession = PrivacyPreservingURLSessionFactory.make()
    ) {
        self.configuration = configuration
        self.codec = codec
        self.appAttest = appAttest
        self.session = session
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func submit(_ submission: ShieldedSpendSubmission) async throws -> RelaySubmissionReceipt {
        guard configuration.supportsRelaySubmission else {
            throw WalletError.featureUnavailable("Relay submission")
        }
        guard let baseURL = configuration.relayIngressURL else {
            throw WalletError.misconfiguredService("Relay ingress")
        }

        let body = try encoder.encode(submission)
        guard let attestation = try await appAttest.assertion(for: body) else {
            throw WalletError.appAttestUnavailable
        }
        let envelope = try codec.makeEnvelope(kind: .relaySubmission, payload: body, attestation: attestation)

        var request = URLRequest(url: baseURL.appending(path: "submit"))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(envelope.envelopeID.uuidString, forHTTPHeaderField: "X-Numi-Envelope-ID")
        request.setValue(envelope.kind.rawValue, forHTTPHeaderField: "X-Numi-Envelope-Kind")
        request.setValue(iso8601String(from: envelope.releaseSlot), forHTTPHeaderField: "X-Numi-Release-Slot")
        request.httpBody = try encoder.encode(envelope)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200..<300).contains(statusCode) else {
            throw WalletError.remoteServiceUnavailable("Relay ingress")
        }

        do {
            return try decoder.decode(RelaySubmissionReceipt.self, from: data)
        } catch {
            throw WalletError.invalidRemoteResponse("Relay ingress")
        }
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
