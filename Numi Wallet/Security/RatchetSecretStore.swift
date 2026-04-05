import Foundation
import Security

actor RatchetSecretStore {
    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func store(_ material: RatchetSecretMaterial, relationshipID: UUID) throws {
        let encoded = try encoder.encode(material)
        try keychain.save(
            encoded,
            account: account(for: relationshipID),
            accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            label: "Numi Payment Relationship Ratchet"
        )
    }

    func load(relationshipID: UUID) throws -> RatchetSecretMaterial {
        guard let rawData = try keychain.read(account: account(for: relationshipID)) else {
            throw WalletError.corruptedState
        }
        return try decoder.decode(RatchetSecretMaterial.self, from: rawData)
    }

    func exportSecrets(for relationshipIDs: [UUID]) throws -> [UUID: RatchetSecretMaterial] {
        var exported: [UUID: RatchetSecretMaterial] = [:]
        for relationshipID in relationshipIDs {
            exported[relationshipID] = try load(relationshipID: relationshipID)
        }
        return exported
    }

    func importSecrets(_ secrets: [UUID: RatchetSecretMaterial]) throws {
        for (relationshipID, material) in secrets {
            try store(material, relationshipID: relationshipID)
        }
    }

    func deleteSecrets(for relationshipIDs: [UUID]) throws {
        for relationshipID in relationshipIDs {
            try keychain.delete(account: account(for: relationshipID))
        }
    }

    private func account(for relationshipID: UUID) -> String {
        "ratchet-secret.\(relationshipID.uuidString)"
    }
}
