import Foundation
import LocalAuthentication
import Security

final class KeychainStore {
    nonisolated private let service: String

    nonisolated init(service: String = Bundle.main.bundleIdentifier ?? "numi.wallet") {
        self.service = service
    }

    nonisolated func save(
        _ data: Data,
        account: String,
        accessControl: SecAccessControl? = nil,
        accessible: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        label: String? = nil
    ) throws {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecUseDataProtectionKeychain as String] = true

        if let label {
            query[kSecAttrLabel as String] = label
        }

        if let accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = accessible
        }

        let updateQuery = baseQuery(account: account)
        let status = SecItemCopyMatching(updateQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw keychainError(updateStatus) }
        case errSecItemNotFound:
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw keychainError(addStatus) }
        default:
            throw keychainError(status)
        }
    }

    nonisolated func read(account: String, authenticationContext: LAContext? = nil, prompt: String? = nil) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseDataProtectionKeychain as String] = true

        let effectiveContext: LAContext?
        if let prompt {
            let context = authenticationContext ?? LAContext()
            context.localizedReason = prompt
            effectiveContext = context
        } else {
            effectiveContext = authenticationContext
        }

        if let effectiveContext {
            query[kSecUseAuthenticationContext as String] = effectiveContext
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled:
            throw WalletError.userCancelled
        default:
            throw keychainError(status)
        }
    }

    nonisolated func exists(account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseDataProtectionKeychain as String] = true
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    nonisolated func delete(account: String) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    nonisolated private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    nonisolated private func keychainError(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
