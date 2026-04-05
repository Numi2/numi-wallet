import Foundation

private struct DiscoveryRegistrationPayload: Codable {
    var aliasToken: Data
    var descriptor: PrivateReceiveDescriptor
}

private struct DiscoveryLookupPayload: Codable {
    var aliasToken: Data
}

actor DiscoveryClient {
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

    func register(alias: String, descriptor: PrivateReceiveDescriptor) async throws {
        guard configuration.supportsAliasDiscovery else {
            throw WalletError.featureUnavailable("Alias discovery")
        }
        guard let baseURL = configuration.discoveryURL else {
            throw WalletError.misconfiguredService("Discovery service")
        }
        let payload = DiscoveryRegistrationPayload(
            aliasToken: codec.blindedAliasToken(alias: alias),
            descriptor: descriptor
        )
        let body = try encoder.encode(payload)
        let attestation = try await makeRequiredAttestation(for: body, requiresRemoteDelivery: configuration.discoveryURL != nil)
        let envelope = try codec.makeEnvelope(kind: .discoveryRegistration, payload: body, attestation: attestation)

        _ = try await post(path: "register", envelope: envelope, baseURL: baseURL)
    }

    func resolve(alias: String) async throws -> PrivateReceiveDescriptor? {
        guard configuration.supportsAliasDiscovery else {
            throw WalletError.featureUnavailable("Alias discovery")
        }
        guard let baseURL = configuration.discoveryURL else {
            throw WalletError.misconfiguredService("Discovery service")
        }
        let token = codec.blindedAliasToken(alias: alias)

        let payload = DiscoveryLookupPayload(aliasToken: token)
        let body = try encoder.encode(payload)
        let attestation = try await makeRequiredAttestation(for: body, requiresRemoteDelivery: true)
        let envelope = try codec.makeEnvelope(kind: .discoveryLookup, payload: body, attestation: attestation)
        let response = try await post(path: "resolve", envelope: envelope, baseURL: baseURL)

        if response.isEmpty {
            return nil
        }

        return try decoder.decode(PrivateReceiveDescriptor.self, from: response)
    }

    private func post(path: String, envelope: PaddedEnvelope, baseURL: URL) async throws -> Data {
        let requestURL = baseURL.appending(path: path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(envelope.envelopeID.uuidString, forHTTPHeaderField: "X-Numi-Envelope-ID")
        request.setValue(envelope.kind.rawValue, forHTTPHeaderField: "X-Numi-Envelope-Kind")
        request.setValue(iso8601String(from: envelope.releaseSlot), forHTTPHeaderField: "X-Numi-Release-Slot")
        request.httpBody = try encoder.encode(envelope)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200..<300).contains(statusCode) else {
            throw WalletError.remoteServiceUnavailable("Discovery service")
        }
        return data
    }

    private func makeRequiredAttestation(for body: Data, requiresRemoteDelivery: Bool) async throws -> AppAttestArtifact? {
        let attestation = try await appAttest.assertion(for: body)
        if requiresRemoteDelivery, attestation == nil {
            throw WalletError.appAttestUnavailable
        }
        return attestation
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
