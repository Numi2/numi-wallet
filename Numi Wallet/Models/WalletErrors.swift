import Foundation

enum WalletError: LocalizedError {
    case authorityOnly
    case recoveryPeerOnly
    case walletNotInitialized
    case vaultLocked
    case peerPresenceRequired
    case companionAuthenticationRejected
    case biometricAuthenticationUnavailable
    case recoveryQuorumIncomplete
    case secureEnclaveUnavailable
    case appAttestUnsupported
    case appAttestUnavailable
    case descriptorVerificationFailed
    case descriptorUpgradeRequired
    case invalidRecoveryPackage
    case invalidRecoveryTransfer
    case invalidPeerTrustSession
    case peerTrustExpired
    case proofOffloadPeerUnavailable
    case featureUnavailable(String)
    case insufficientFunds
    case missingPIRState
    case misconfiguredService(String)
    case invalidRemoteResponse(String)
    case remoteServiceUnavailable(String)
    case corruptedState
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .authorityOnly:
            return "This action is available only on the authority iPhone."
        case .recoveryPeerOnly:
            return "This action is available only on a paired recovery peer."
        case .walletNotInitialized:
            return "The wallet has not been initialized on this device."
        case .vaultLocked:
            return "The vault is locked."
        case .peerPresenceRequired:
            return "A paired peer must be locally present to unlock the vault or spend from it."
        case .companionAuthenticationRejected:
            return "Spend approval requires local biometric authentication and device passcode-backed access control."
        case .biometricAuthenticationUnavailable:
            return "Biometric authentication is unavailable on this device."
        case .recoveryQuorumIncomplete:
            return "Recovery requires both enrolled peers and local authentication on each peer."
        case .secureEnclaveUnavailable:
            return "Secure Enclave-backed keys are unavailable on this device."
        case .appAttestUnsupported:
            return "App Attest is not supported on this platform."
        case .appAttestUnavailable:
            return "App Attest could not produce a usable assertion."
        case .descriptorVerificationFailed:
            return "The receive descriptor could not be verified."
        case .descriptorUpgradeRequired:
            return "The receive descriptor is incomplete for Numi's sovereign transport and tag architecture."
        case .invalidRecoveryPackage:
            return "The recovery package is invalid or incomplete."
        case .invalidRecoveryTransfer:
            return "The recovery transfer envelope could not be verified."
        case .invalidPeerTrustSession:
            return "The peer trust session could not be verified."
        case .peerTrustExpired:
            return "The peer trust session has expired and must be re-established."
        case .proofOffloadPeerUnavailable:
            return "A paired Mac proof coprocessor is not available."
        case .featureUnavailable(let feature):
            return "\(feature) is not enabled for the current coin profile."
        case .insufficientFunds:
            return "The selected wallet tier does not currently have a spendable note that satisfies this amount and fee ceiling."
        case .missingPIRState:
            return "Shielded state is not ready. Refresh PIR state before spending."
        case .misconfiguredService(let service):
            return "\(service) is not configured for this build."
        case .invalidRemoteResponse(let service):
            return "\(service) returned an invalid response."
        case .remoteServiceUnavailable(let service):
            return "\(service) is unavailable in the current configuration."
        case .corruptedState:
            return "The stored wallet state is corrupted."
        case .userCancelled:
            return "The user cancelled the operation."
        }
    }
}
