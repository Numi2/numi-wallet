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
    case invalidRecoveryTransferDocument
    case invalidRecoveryTransferQRCode
    case invalidPeerTrustSession
    case invalidLocalPeerSession
    case invalidPeerPresenceAssertion
    case peerTrustExpired
    case localPeerUnavailable
    case localPeerTransportUnavailable
    case proofOffloadPeerUnavailable
    case featureUnavailable(String)
    case insufficientFunds
    case missingPIRState
    case misconfiguredService(String)
    case invalidRemoteResponse(String)
    case invalidShieldedPayload(String)
    case remoteServiceUnavailable(String)
    case invalidProofArtifact(String)
    case resumableProofPending(String)
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
            return "A paired peer must be locally present to unlock the vault, spend from it, or exchange peer recovery material."
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
            return "The recovery transfer envelope is invalid, unsigned, or no longer bound to the required trust context."
        case .invalidRecoveryTransferDocument:
            return "The recovery transfer document is malformed, corrupted, or fails Numi's canonical integrity check."
        case .invalidRecoveryTransferQRCode:
            return "The recovery transfer QR chunk set is incomplete, corrupted, or no longer matches a canonical Numi transfer document."
        case .invalidPeerTrustSession:
            return "The peer trust session could not be verified."
        case .invalidLocalPeerSession:
            return "The authenticated local peer session could not be established or verified."
        case .invalidPeerPresenceAssertion:
            return "The peer presence assertion is invalid, expired, or no longer bound to the active trust session."
        case .peerTrustExpired:
            return "The peer trust session has expired and must be re-established."
        case .localPeerUnavailable:
            return "No compatible local peer endpoint is currently available for authenticated pairing."
        case .localPeerTransportUnavailable:
            return "The local authenticated transport is unavailable on this device right now."
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
        case .invalidShieldedPayload(let detail):
            return "The incoming shielded payload is invalid: \(detail)"
        case .remoteServiceUnavailable(let service):
            return "\(service) is unavailable in the current configuration."
        case .invalidProofArtifact(let detail):
            return "The local Tachyon proof artifact is invalid: \(detail)"
        case .resumableProofPending(let detail):
            return "The local proof lane stopped before authorization. \(detail)"
        case .corruptedState:
            return "The stored wallet state is corrupted."
        case .userCancelled:
            return "The user cancelled the operation."
        }
    }
}
