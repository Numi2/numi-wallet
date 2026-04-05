import Foundation
import Security

actor DescriptorSecretStore {
    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func store(_ material: DescriptorPrivateMaterial, descriptorID: UUID, tier: WalletTier) throws {
        let encoded = try encoder.encode(material)
        try keychain.save(
            encoded,
            account: account(for: descriptorID, tier: tier),
            accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            label: "Numi \(tier.displayName) Descriptor Secret"
        )
    }

    func load(descriptorID: UUID, tier: WalletTier) throws -> DescriptorPrivateMaterial {
        guard let secretData = try keychain.read(account: account(for: descriptorID, tier: tier)) else {
            throw WalletError.corruptedState
        }
        return try decodeMaterial(secretData)
    }

    func exportSecrets(for descriptorIDs: [UUID], tier: WalletTier) throws -> [UUID: DescriptorPrivateMaterial] {
        var exported: [UUID: DescriptorPrivateMaterial] = [:]
        for descriptorID in descriptorIDs {
            exported[descriptorID] = try load(descriptorID: descriptorID, tier: tier)
        }
        return exported
    }

    func importSecrets(_ secrets: [UUID: DescriptorPrivateMaterial], tier: WalletTier) throws {
        for (descriptorID, material) in secrets {
            try store(material, descriptorID: descriptorID, tier: tier)
        }
    }

    func deleteSecrets(for descriptorIDs: [UUID], tier: WalletTier) throws {
        for descriptorID in descriptorIDs {
            try keychain.delete(account: account(for: descriptorID, tier: tier))
        }
    }

    private func decodeMaterial(_ rawData: Data) throws -> DescriptorPrivateMaterial {
        if let material = try? decoder.decode(DescriptorPrivateMaterial.self, from: rawData) {
            return material
        }

        return DescriptorPrivateMaterial(deliveryKey: rawData, taggingKey: Data())
    }

    private func account(for descriptorID: UUID, tier: WalletTier) -> String {
        "descriptor-secret.\(tier.rawValue).\(descriptorID.uuidString)"
    }
}
