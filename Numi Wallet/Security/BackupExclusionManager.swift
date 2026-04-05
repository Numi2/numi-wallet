import Foundation

#if canImport(UIKit)
import UIKit
#endif

final class BackupExclusionManager {
    nonisolated private let fileManager = FileManager.default
    nonisolated private let containerDirectoryName = "SovereignState"

    nonisolated func walletContainerURL() throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var containerURL = baseURL.appendingPathComponent(containerDirectoryName, isDirectory: true)

        if !fileManager.fileExists(atPath: containerURL.path) {
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
        }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try containerURL.setResourceValues(values)

        #if canImport(UIKit)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: containerURL.path
        )
        #endif

        return containerURL
    }

    nonisolated func stateFileURL() throws -> URL {
        try walletContainerURL().appendingPathComponent("wallet-state.json", isDirectory: false)
    }

    nonisolated func stateFileURL(deviceID: String, role: DeviceRole) throws -> URL {
        let sanitizedDeviceID = deviceID.replacingOccurrences(of: "/", with: "-")
        let filename = "wallet-state-\(role.rawValue)-\(sanitizedDeviceID).json"
        return try walletContainerURL().appendingPathComponent(filename, isDirectory: false)
    }

    nonisolated func trustLedgerFileURL(deviceID: String, role: DeviceRole) throws -> URL {
        let sanitizedDeviceID = deviceID.replacingOccurrences(of: "/", with: "-")
        let filename = "trust-ledger-\(role.rawValue)-\(sanitizedDeviceID).json"
        return try walletContainerURL().appendingPathComponent(filename, isDirectory: false)
    }
}
