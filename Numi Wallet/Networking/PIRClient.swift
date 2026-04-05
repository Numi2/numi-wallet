import Foundation

struct PIRTransportReceipt: Sendable {
    var queryClass: PIRQueryClass
    var provider: PIRProviderIdentity
    var requestDigest: Data
    var responseDigest: Data
    var receivedAt: Date
}

struct PIRVerifiedResult<Response: Sendable>: Sendable {
    var response: Response
    var receipt: PIRTransportReceipt
}

private enum PIREndpoint {
    case merklePaths
    case nullifiers
    case tags

    var path: String {
        switch self {
        case .merklePaths:
            return "merkle-paths"
        case .nullifiers:
            return "nullifiers"
        case .tags:
            return "tags"
        }
    }

    var kind: EnvelopeKind {
        switch self {
        case .merklePaths:
            return .pirMerklePaths
        case .nullifiers:
            return .pirNullifiers
        case .tags:
            return .pirTags
        }
    }

    var queryClass: PIRQueryClass {
        switch self {
        case .merklePaths:
            return .merklePaths
        case .nullifiers:
            return .nullifierStatuses
        case .tags:
            return .tagDiscovery
        }
    }
}

actor PIRClient {
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
        session: URLSession = PrivacyPreservingURLSessionFactory.make(timeout: 45)
    ) {
        self.configuration = configuration
        self.codec = codec
        self.appAttest = appAttest
        self.session = session
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchMerklePaths(for commitments: [Data]) async throws -> PIRVerifiedResult<PIRMerklePathResponse> {
        guard configuration.supportsPIRStateUpdates else {
            throw WalletError.featureUnavailable("PIR state updates")
        }
        return try await post(
            endpoint: .merklePaths,
            requestBody: PIRMerklePathRequest(noteCommitments: commitments),
            responseType: PIRMerklePathResponse.self,
            budget: configuration.pirEnvelopeSize
        )
    }

    func fetchNullifierStatuses(_ nullifiers: [Data]) async throws -> PIRVerifiedResult<PIRNullifierStatusResponse> {
        guard configuration.supportsPIRStateUpdates else {
            throw WalletError.featureUnavailable("PIR state updates")
        }
        return try await post(
            endpoint: .nullifiers,
            requestBody: PIRNullifierStatusRequest(nullifiers: nullifiers),
            responseType: PIRNullifierStatusResponse.self,
            budget: configuration.pirEnvelopeSize
        )
    }

    func fetchTagMatches(_ tags: [Data]) async throws -> PIRVerifiedResult<PIRTagLookupResponse> {
        guard configuration.supportsPIRStateUpdates else {
            throw WalletError.featureUnavailable("PIR state updates")
        }
        return try await post(
            endpoint: .tags,
            requestBody: PIRTagLookupRequest(tags: tags),
            responseType: PIRTagLookupResponse.self,
            budget: configuration.pirEnvelopeSize
        )
    }

    private func post<Request: Encodable, Response: Decodable & Sendable>(
        endpoint: PIREndpoint,
        requestBody: Request,
        responseType: Response.Type,
        budget: Int
    ) async throws -> PIRVerifiedResult<Response> {
        let (baseURL, provider) = try selectedProvider()
        let body = try encodeRequestBody(requestBody)
        let requestDigest = TachyonSupport.digest(body)
        let envelope = try await makeEnvelope(kind: endpoint.kind, body: body, budget: budget)

        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = session.configuration.timeoutIntervalForRequest
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(envelope.envelopeID.uuidString, forHTTPHeaderField: "X-Numi-Envelope-ID")
        request.setValue(envelope.kind.rawValue, forHTTPHeaderField: "X-Numi-Envelope-Kind")
        request.setValue(iso8601String(from: envelope.releaseSlot), forHTTPHeaderField: "X-Numi-Release-Slot")
        request.httpBody = try encoder.encode(envelope)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200..<300).contains(statusCode) else {
            throw WalletError.remoteServiceUnavailable("PIR service")
        }

        do {
            let decodedResponse = try decoder.decode(responseType, from: data)
            return PIRVerifiedResult(
                response: decodedResponse,
                receipt: PIRTransportReceipt(
                    queryClass: endpoint.queryClass,
                    provider: provider,
                    requestDigest: requestDigest,
                    responseDigest: TachyonSupport.digest(data),
                    receivedAt: Date()
                )
            )
        } catch {
            throw WalletError.invalidRemoteResponse("PIR service")
        }
    }

    private func selectedProvider() throws -> (URL, PIRProviderIdentity) {
        guard let baseURL = configuration.pirURL else {
            throw WalletError.misconfiguredService("PIR service")
        }
        let displayName = baseURL.host(percentEncoded: false) ?? "pir-provider"
        let portSuffix = baseURL.port.map { ":\($0)" } ?? ""
        let serviceOrigin = "\(baseURL.scheme ?? "https")://\(displayName)\(portSuffix)"
        return (
            baseURL,
            PIRProviderIdentity(
                id: providerID(for: serviceOrigin),
                displayName: displayName,
                serviceOrigin: serviceOrigin
            )
        )
    }

    private func encodeRequestBody<Request: Encodable>(_ requestBody: Request) throws -> Data {
        try encoder.encode(requestBody)
    }

    private func makeEnvelope(kind: EnvelopeKind, body: Data, budget: Int) async throws -> PaddedEnvelope {
        let attestation = try await requiredAttestation(for: body)
        return try codec.makeEnvelope(kind: kind, payload: body, attestation: attestation, budget: budget)
    }

    private func requiredAttestation(for body: Data) async throws -> AppAttestArtifact {
        guard let artifact = try await appAttest.assertion(for: body) else {
            throw WalletError.appAttestUnavailable
        }
        return artifact
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    private func providerID(for serviceOrigin: String) -> String {
        let digest = TachyonSupport.digest(string: serviceOrigin)
        let prefix = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
        return "pir-\(prefix)"
    }
}
