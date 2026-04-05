import CryptoKit
import Foundation
import LocalAuthentication
import Security

private struct StoredSigningKeyReference: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case secureEnclaveMLDSA87
    }

    var kind: Kind
    var data: Data
}

actor SecureEnclaveKeyManager {
    private enum Account {
        static let authorityKey = "authority-root-signing-key"
        static let peerIdentityKey = "peer-identity-signing-key"
        static let spendAuthorizationToken = "authority-spend-authorization-token"
        static let vaultWrappingKey = "authority-vault-wrapping-key"
    }

    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func ensureAuthorityPublicKey() throws -> Data {
        try ensureSigningKey(account: Account.authorityKey).publicKey
    }

    func ensurePeerIdentityPublicKey() throws -> Data {
        try ensureSigningKey(account: Account.peerIdentityKey).publicKey
    }

    func signAuthorityPayload(_ payload: Data) throws -> Data {
        try ensureSigningKey(account: Account.authorityKey).sign(payload)
    }

    func signPeerPayload(_ payload: Data) throws -> Data {
        try ensureSigningKey(account: Account.peerIdentityKey).sign(payload)
    }

    func verifyAuthoritySignature(signature: Data, payload: Data, publicKey: Data) throws -> Bool {
        let key = try MLDSA87.PublicKey(rawRepresentation: publicKey)
        return key.isValidSignature(signature, for: payload)
    }

    func verifyPeerSignature(signature: Data, payload: Data, publicKey: Data) throws -> Bool {
        let key = try MLDSA87.PublicKey(rawRepresentation: publicKey)
        return key.isValidSignature(signature, for: payload)
    }

    func ensureSpendAuthorizationToken() throws {
        if keychain.exists(account: Account.spendAuthorizationToken) {
            return
        }
        let token = randomData(length: 32)
        try keychain.save(
            token,
            account: Account.spendAuthorizationToken,
            accessControl: spendAccessControl(),
            label: "Numi Spend Authorization"
        )
    }

    func validateSpendAuthorization(using context: LAContext) throws {
        _ = try keychain.read(
            account: Account.spendAuthorizationToken,
            authenticationContext: context,
            prompt: "Approve sovereign wallet spend"
        )
    }

    func ensureVaultWrappingKey() throws {
        if keychain.exists(account: Account.vaultWrappingKey) {
            return
        }
        try keychain.save(
            randomData(length: 32),
            account: Account.vaultWrappingKey,
            accessControl: spendAccessControl(),
            label: "Numi Vault Wrapping Key"
        )
    }

    func provisionFreshVaultWrappingKey() throws -> SymmetricKey {
        let rawKey = randomData(length: 32)
        try keychain.save(
            rawKey,
            account: Account.vaultWrappingKey,
            accessControl: spendAccessControl(),
            label: "Numi Vault Wrapping Key"
        )
        return SymmetricKey(data: rawKey)
    }

    func loadVaultWrappingKey(using context: LAContext) throws -> SymmetricKey {
        guard let data = try keychain.read(
            account: Account.vaultWrappingKey,
            authenticationContext: context,
            prompt: "Unlock sovereign wallet vault"
        ) else {
            throw WalletError.vaultLocked
        }
        return SymmetricKey(data: data)
    }

    func destroyLocalVaultWrappingKey() throws {
        try keychain.delete(account: Account.vaultWrappingKey)
    }

    private func ensureSigningKey(account: String) throws -> AnySigningKey {
        if let storedData = try keychain.read(account: account) {
            let stored = try decoder.decode(StoredSigningKeyReference.self, from: storedData)
            return try AnySigningKey(stored: stored)
        }

        let key = try AnySigningKey.makeBestAvailable()
        let stored = key.storedReference
        let data = try encoder.encode(stored)
        try keychain.save(data, account: account, label: account)
        return key
    }

    private func spendAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let control = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .or, .devicePasscode],
            &error
        ) else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw WalletError.secureEnclaveUnavailable
        }
        return control
    }

    private func randomData(length: Int) -> Data {
        Data((0..<length).map { _ in UInt8.random(in: .min ... .max) })
    }
}

private struct AnySigningKey: Sendable {
    private let boxed: KeyBox
    let storedReference: StoredSigningKeyReference
    let publicKey: Data

    private init(boxed: KeyBox, storedReference: StoredSigningKeyReference, publicKey: Data) {
        self.boxed = boxed
        self.storedReference = storedReference
        self.publicKey = publicKey
    }

    static func makeBestAvailable() throws -> AnySigningKey {
        let accessControl = try secureEnclaveAccessControl()
        let key = try SecureEnclave.MLDSA87.PrivateKey(accessControl: accessControl, authenticationContext: LAContext())
        return AnySigningKey(
            boxed: .secureEnclave(key),
            storedReference: StoredSigningKeyReference(kind: .secureEnclaveMLDSA87, data: key.dataRepresentation),
            publicKey: key.publicKey.rawRepresentation
        )
    }

    init(stored: StoredSigningKeyReference) throws {
        switch stored.kind {
        case .secureEnclaveMLDSA87:
            let key = try SecureEnclave.MLDSA87.PrivateKey(
                dataRepresentation: stored.data,
                authenticationContext: LAContext()
            )
            self.init(
                boxed: .secureEnclave(key),
                storedReference: stored,
                publicKey: key.publicKey.rawRepresentation
            )
        }
    }

    func sign(_ payload: Data) throws -> Data {
        switch boxed {
        case .secureEnclave(let key):
            return try key.signature(for: payload)
        }
    }

    private static func secureEnclaveAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let control = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &error
        ) else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw WalletError.secureEnclaveUnavailable
        }
        return control
    }

    private enum KeyBox: Sendable {
        case secureEnclave(SecureEnclave.MLDSA87.PrivateKey)
    }
}
