import CryptoKit
import Foundation

private struct StateIntegrityEnvelope: Codable {
    var version: Int
    var payload: Data
    var authenticationCode: Data
}

struct StateIntegrityProvider {
    private enum Account {
        static let integrityKey = "wallet-state-integrity-key"
    }

    private let keychain: KeychainStore

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func seal(_ payload: Data) throws -> Data {
        let key = try loadOrCreateKey()
        let mac = Data(HMAC<SHA256>.authenticationCode(for: payload, using: key))
        let envelope = StateIntegrityEnvelope(version: 1, payload: payload, authenticationCode: mac)
        return try JSONEncoder().encode(envelope)
    }

    func open(_ sealedData: Data) throws -> Data {
        let envelope = try JSONDecoder().decode(StateIntegrityEnvelope.self, from: sealedData)
        let key = try loadOrCreateKey()
        let expectedMac = HMAC<SHA256>.authenticationCode(for: envelope.payload, using: key)
        guard Data(expectedMac) == envelope.authenticationCode else {
            throw WalletError.corruptedState
        }
        return envelope.payload
    }

    func isSealedEnvelope(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(StateIntegrityEnvelope.self, from: data)) != nil
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try keychain.read(account: Account.integrityKey) {
            return SymmetricKey(data: existing)
        }

        let material = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        try keychain.save(
            material,
            account: Account.integrityKey,
            accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            label: "Numi State Integrity Key"
        )
        return SymmetricKey(data: material)
    }
}
