import Foundation
import LocalAuthentication
import Security

actor RecoveryPeerVault {
    private enum Account {
        static let recoveryShare = "recovery-peer-share"
    }

    private let role: DeviceRole
    private let keychain: KeychainStore
    private let authClient: LocalAuthenticationClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        role: DeviceRole,
        keychain: KeychainStore = KeychainStore(),
        authClient: LocalAuthenticationClient = LocalAuthenticationClient()
    ) {
        self.role = role
        self.keychain = keychain
        self.authClient = authClient
    }

    func hasShare() -> Bool {
        keychain.exists(account: Account.recoveryShare)
    }

    func storeShare(_ share: RecoveryShareEnvelope) async throws {
        let context = try await authClient.authenticateDeviceOwner(reason: "Approve local recovery share import")
        try storeShare(share, authorizationContext: context)
    }

    func storeShare(_ share: RecoveryShareEnvelope, authorizationContext: LAContext) throws {
        guard role.isRecoveryPeer else { throw WalletError.recoveryPeerOnly }
        _ = authorizationContext
        try validate(share: share)

        try keychain.save(
            try encoder.encode(share),
            account: Account.recoveryShare,
            accessControl: recoveryAccessControl(),
            label: "Numi Recovery Share"
        )
    }

    func exportShare() async throws -> RecoveryShareEnvelope {
        guard role.isRecoveryPeer else { throw WalletError.recoveryPeerOnly }
        let context = try await authClient.authenticateBiometric(reason: "Approve local recovery share export")
        return try exportShare(authorizationContext: context)
    }

    func exportShare(authorizationContext context: LAContext) throws -> RecoveryShareEnvelope {
        guard role.isRecoveryPeer else { throw WalletError.recoveryPeerOnly }
        guard let data = try keychain.read(
            account: Account.recoveryShare,
            authenticationContext: context,
            prompt: "Approve recovery share export"
        ) else {
            throw WalletError.recoveryQuorumIncomplete
        }
        return try decoder.decode(RecoveryShareEnvelope.self, from: data)
    }

    func destroyShare() throws {
        try keychain.delete(account: Account.recoveryShare)
    }

    private func recoveryAccessControl() throws -> SecAccessControl {
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
            throw WalletError.recoveryQuorumIncomplete
        }
        return control
    }

    private func validate(share: RecoveryShareEnvelope) throws {
        let expectedPeerKind: PeerKind = switch role {
        case .authorityPhone:
            throw WalletError.recoveryPeerOnly
        case .recoveryPad:
            .pad
        case .recoveryMac:
            .mac
        }

        guard share.peerKind == expectedPeerKind else {
            throw WalletError.invalidRecoveryPackage
        }
        guard !share.fragment.isEmpty,
              !share.recoveryPackage.sealedState.isEmpty,
              !share.recoveryPackage.stateDigest.isEmpty,
              !share.rootKeyDigest.isEmpty else {
            throw WalletError.invalidRecoveryPackage
        }
    }
}
