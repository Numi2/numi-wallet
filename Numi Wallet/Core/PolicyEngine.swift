import Foundation

struct PolicyEvaluation: Sendable {
    var dayVisible: Bool
    var vaultVisible: Bool
    var vaultSpendAllowed: Bool
    var sensitiveUIVisible: Bool
}

struct PolicyEngine: Sendable {
    func evaluate(
        policy: PolicySnapshot,
        peerPresent: Bool,
        vaultAuthSatisfied: Bool,
        privacyExposureDetected: Bool
    ) -> PolicyEvaluation {
        let sensitiveUIVisible = policy.panicState == .normal && !privacyExposureDetected
        let vaultVisible = policy.panicState == .normal
            && sensitiveUIVisible
            && (!policy.requirePeerForVaultVisibility || peerPresent)
            && vaultAuthSatisfied
        let vaultSpendAllowed = vaultVisible && (!policy.requirePeerForVaultSpend || peerPresent)

        return PolicyEvaluation(
            dayVisible: sensitiveUIVisible,
            vaultVisible: vaultVisible,
            vaultSpendAllowed: vaultSpendAllowed,
            sensitiveUIVisible: sensitiveUIVisible
        )
    }

    func requireVaultVisibility(
        policy: PolicySnapshot,
        peerPresent: Bool,
        vaultAuthSatisfied: Bool,
        privacyExposureDetected: Bool
    ) throws {
        let evaluation = evaluate(
            policy: policy,
            peerPresent: peerPresent,
            vaultAuthSatisfied: vaultAuthSatisfied,
            privacyExposureDetected: privacyExposureDetected
        )
        guard evaluation.vaultVisible else {
            if policy.requirePeerForVaultVisibility && !peerPresent {
                throw WalletError.peerPresenceRequired
            }
            throw WalletError.vaultLocked
        }
    }

    func requireSpend(
        from tier: WalletTier,
        policy: PolicySnapshot,
        peerPresent: Bool,
        spendAuthSatisfied: Bool,
        privacyExposureDetected: Bool
    ) throws {
        switch tier {
        case .day:
            guard spendAuthSatisfied && !privacyExposureDetected else {
                throw WalletError.companionAuthenticationRejected
            }
        case .vault:
            let evaluation = evaluate(
                policy: policy,
                peerPresent: peerPresent,
                vaultAuthSatisfied: spendAuthSatisfied,
                privacyExposureDetected: privacyExposureDetected
            )
            guard evaluation.vaultSpendAllowed else {
                if policy.requirePeerForVaultSpend && !peerPresent {
                    throw WalletError.peerPresenceRequired
                }
                throw WalletError.vaultLocked
            }
        }
    }
}
