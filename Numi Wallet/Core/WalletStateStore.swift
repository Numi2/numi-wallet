import Foundation

actor WalletStateStore {
    private let backupManager: BackupExclusionManager
    private let integrityProvider: StateIntegrityProvider
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        backupManager: BackupExclusionManager = BackupExclusionManager(),
        integrityProvider: StateIntegrityProvider = StateIntegrityProvider()
    ) {
        self.backupManager = backupManager
        self.integrityProvider = integrityProvider
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load(deviceID: String, role: DeviceRole) throws -> WalletProfile {
        let stateURL = try backupManager.stateFileURL(deviceID: deviceID, role: role)
        let legacyURL = try backupManager.stateFileURL()

        if !FileManager.default.fileExists(atPath: stateURL.path),
           FileManager.default.fileExists(atPath: legacyURL.path) {
            try migrateLegacyStateIfNeeded(from: legacyURL, to: stateURL, deviceID: deviceID, role: role)
        }

        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return WalletProfile.empty(deviceID: deviceID, role: role)
        }

        let rawData = try Data(contentsOf: stateURL)
        do {
            let data = try decodeStoredProfileData(rawData)
            return try decoder.decode(WalletProfile.self, from: data)
        } catch {
            throw WalletError.corruptedState
        }
    }

    func save(_ profile: WalletProfile) throws {
        var stateURL = try backupManager.stateFileURL(deviceID: profile.deviceID, role: profile.role)
        let encodedProfile = try encoder.encode(profile)
        let sealedData = try integrityProvider.seal(encodedProfile)
        try sealedData.write(to: stateURL, options: [.atomic])

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try stateURL.setResourceValues(values)
    }

    private func migrateLegacyStateIfNeeded(from legacyURL: URL, to scopedURL: URL, deviceID: String, role: DeviceRole) throws {
        let rawData = try Data(contentsOf: legacyURL)
        let data = try decodeStoredProfileData(rawData)
        let profile = try decoder.decode(WalletProfile.self, from: data)
        guard profile.deviceID == deviceID, profile.role == role else {
            return
        }

        var scopedURL = scopedURL
        let sealedData = try integrityProvider.seal(data)
        try sealedData.write(to: scopedURL, options: [.atomic])

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try scopedURL.setResourceValues(values)
    }

    private func decodeStoredProfileData(_ rawData: Data) throws -> Data {
        if integrityProvider.isSealedEnvelope(rawData) {
            return try integrityProvider.open(rawData)
        }
        return rawData
    }
}
