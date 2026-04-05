import Foundation

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

    func fetchMerklePaths(for commitments: [Data]) async throws -> PIRMerklePathResponse {
        guard configuration.supportsPIRStateUpdates else {
            throw WalletError.featureUnavailable("PIR state updates")
        }
        return try await post(
            path: "merkle-paths",
            kind: .pirMerklePaths,
            requestBody: PIRMerklePathRequest(noteCommitments: commitments),
            responseType: PIRMerklePathResponse.self,
            budget: configuration.pirEnvelopeSize
        )
    }

    func fetchNullifierStatuses(_ nullifiers: [Data]) async throws -> PIRNullifierStatusResponse {
        guard configuration.supportsPIRStateUpdates else {
            throw WalletError.featureUnavailable("PIR state updates")
        }
        return try await post(
            path: "nullifiers",
            kind: .pirNullifiers,
            requestBody: PIRNullifierStatusRequest(nullifiers: nullifiers),
            responseType: PIRNullifierStatusResponse.self,
            budget: configuration.pirEnvelopeSize
        )
    }

    func fetchTagMatches(_ tags: [Data]) async throws -> PIRTagLookupResponse {
        guard configuration.supportsPIRStateUpdates else {
            throw WalletError.featureUnavailable("PIR state updates")
        }
        return try await post(
            path: "tags",
            kind: .pirTags,
            requestBody: PIRTagLookupRequest(tags: tags),
            responseType: PIRTagLookupResponse.self,
            budget: configuration.pirEnvelopeSize
        )
    }

    private func post<Request: Encodable, Response: Decodable>(
        path: String,
        kind: EnvelopeKind,
        requestBody: Request,
        responseType: Response.Type,
        budget: Int
    ) async throws -> Response {
        guard let baseURL = configuration.pirURL else {
            throw WalletError.misconfiguredService("PIR service")
        }

        let body = try encoder.encode(requestBody)
        let attestation = try await requiredAttestation(for: body)
        let envelope = try codec.makeEnvelope(kind: kind, payload: body, attestation: attestation, budget: budget)

        var request = URLRequest(url: baseURL.appending(path: path))
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
            return try decoder.decode(responseType, from: data)
        } catch {
            throw WalletError.invalidRemoteResponse("PIR service")
        }
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
}
