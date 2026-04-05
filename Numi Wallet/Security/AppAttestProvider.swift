import CryptoKit
import Foundation

#if canImport(DeviceCheck)
import DeviceCheck
#endif

actor AppAttestProvider {
    private let keychain: KeychainStore
    private let keyAccount = "app-attest-key-id"

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func assertion(for challenge: Data) async throws -> AppAttestArtifact? {
        #if canImport(DeviceCheck) && !targetEnvironment(simulator)
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            return nil
        }

        let keyID = try await ensureKeyID(service: service)
        let clientDataHash = Data(SHA256.hash(data: challenge))
        let assertion = try await generateAssertion(
            service: service,
            keyID: keyID,
            clientDataHash: clientDataHash
        )
        return AppAttestArtifact(
            keyID: keyID,
            clientDataHash: clientDataHash,
            assertion: assertion,
            issuedAt: Date()
        )
        #else
        return nil
        #endif
    }

    #if canImport(DeviceCheck) && !targetEnvironment(simulator)
    private func ensureKeyID(service: DCAppAttestService) async throws -> String {
        if let existing = try keychain.read(account: keyAccount).flatMap({ String(data: $0, encoding: .utf8) }) {
            return existing
        }

        let keyID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            service.generateKey { keyID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let keyID else {
                    continuation.resume(throwing: WalletError.appAttestUnavailable)
                    return
                }
                continuation.resume(returning: keyID)
            }
        }

        try keychain.save(Data(keyID.utf8), account: keyAccount, label: "Numi App Attest Key ID")
        return keyID
    }

    private func generateAssertion(
        service: DCAppAttestService,
        keyID: String,
        clientDataHash: Data
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertion, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let assertion else {
                    continuation.resume(throwing: WalletError.appAttestUnavailable)
                    return
                }
                continuation.resume(returning: assertion)
            }
        }
    }
    #endif
}
