import CryptoKit
import Foundation
import LocalAuthentication

#if canImport(DeviceCheck)
import DeviceCheck
#endif

#if canImport(NearbyInteraction)
import NearbyInteraction
#endif

#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct AppleSecurityPostureClient {
    private let backupManager: BackupExclusionManager

    init(backupManager: BackupExclusionManager = BackupExclusionManager()) {
        self.backupManager = backupManager
    }

    func scan(role: DeviceRole, isScreenCaptureActive: Bool) -> AppleSecurityPosture {
        let capabilities = [
            postQuantumRootCapability(),
            ownerAuthenticationCapability(),
            appAttestationCapability(),
            nearbyTrustCapability(for: role),
            localStateCapability(),
            privacyBoundaryCapability(isScreenCaptureActive: isScreenCaptureActive)
        ]

        let readyCount = capabilities.filter { $0.state == .ready }.count
        let attentionCount = capabilities.filter { $0.state == .attention }.count
        let limitedCount = capabilities.filter { $0.state == .limited }.count

        let headline: String
        if limitedCount > 0 {
            headline = "Apple trust fabric is constrained on this device"
        } else if attentionCount > 0 {
            headline = "Apple trust fabric is mostly ready with visible caveats"
        } else {
            headline = "Apple trust fabric is fully armed for sovereign wallet use"
        }

        let summary = "\(readyCount) of \(capabilities.count) trust anchors are fully ready. \(attentionCount) need attention and \(limitedCount) are materially constrained."

        return AppleSecurityPosture(
            assessedAt: Date(),
            headline: headline,
            summary: summary,
            preferredTrustTransport: preferredTrustTransport(for: role),
            capabilities: capabilities
        )
    }

    private func postQuantumRootCapability() -> AppleSecurityCapability {
        #if targetEnvironment(simulator)
        return AppleSecurityCapability(
            id: .postQuantumRoot,
            title: "Post-Quantum Root",
            shortValue: "Software Fallback",
            detail: "This simulator build uses software ML-DSA storage. Physical devices should bind the wallet root to Secure Enclave hardware.",
            recommendation: "Validate authority flows on a physical iPhone before trusting the hardware boundary.",
            systemImage: "shield.lefthalf.filled",
            state: .attention
        )
        #else
        let secureEnclaveAvailable = SecureEnclave.isAvailable
        return AppleSecurityCapability(
            id: .postQuantumRoot,
            title: "Post-Quantum Root",
            shortValue: secureEnclaveAvailable ? "Secure Enclave ML-DSA" : "Hardware Root Missing",
            detail: secureEnclaveAvailable
                ? "This device can keep the wallet authority key in Secure Enclave-backed ML-DSA storage."
                : "Secure Enclave is unavailable, so the intended hardware root of trust cannot be enforced.",
            recommendation: secureEnclaveAvailable
                ? "Keep the authority root on this device and avoid exporting trust material."
                : "Do not use this device as the long-lived authority iPhone.",
            systemImage: "shield.lefthalf.filled",
            state: secureEnclaveAvailable ? .ready : .limited
        )
        #endif
    }

    private func ownerAuthenticationCapability() -> AppleSecurityCapability {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Device Passcode"

        var ownerError: NSError?
        let canAuthenticateOwner = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &ownerError)

        var biometricError: NSError?
        let canAuthenticateBiometric = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &biometricError)

        let biometryLabel = biometryTypeLabel(context.biometryType)
        if canAuthenticateOwner, canAuthenticateBiometric {
            return AppleSecurityCapability(
                id: .ownerAuthentication,
                title: "Owner Authentication",
                shortValue: "\(biometryLabel) + Passcode",
                detail: "\(biometryLabel) and device passcode are available for vault, recovery, and day-lane approval flows.",
                recommendation: "Keep privileged actions on system authentication surfaces instead of custom prompts.",
                systemImage: "faceid",
                state: .ready
            )
        }

        if canAuthenticateOwner {
            return AppleSecurityCapability(
                id: .ownerAuthentication,
                title: "Owner Authentication",
                shortValue: "Passcode Only",
                detail: "Device-owner authentication is available, but biometric approval is not enrolled or not available on this device.",
                recommendation: "Enroll Face ID or Touch ID before treating this device as a high-trust daily authority.",
                systemImage: "lock.iphone",
                state: .attention
            )
        }

        return AppleSecurityCapability(
            id: .ownerAuthentication,
            title: "Owner Authentication",
            shortValue: "Unavailable",
            detail: ownerError?.localizedDescription ?? "Device-owner authentication is unavailable, which breaks the intended approval model.",
            recommendation: "Do not use this device for authority or recovery roles until device-owner authentication is restored.",
            systemImage: "lock.slash",
            state: .limited
        )
    }

    private func appAttestationCapability() -> AppleSecurityCapability {
        #if targetEnvironment(simulator)
        return AppleSecurityCapability(
            id: .appAttestation,
            title: "App Attestation",
            shortValue: "Simulator Unsupported",
            detail: "App Attest does not operate in Simulator. Physical-device builds should attest server-bound requests.",
            recommendation: "Verify App Attest on physical devices before shipping any remote path.",
            systemImage: "checkmark.shield.fill",
            state: .attention
        )
        #elseif canImport(DeviceCheck)
        let isSupported = DCAppAttestService.shared.isSupported
        return AppleSecurityCapability(
            id: .appAttestation,
            title: "App Attestation",
            shortValue: isSupported ? "App Attest Ready" : "Unavailable",
            detail: isSupported
                ? "This app instance can bind remote requests to a real Apple-signed client through App Attest."
                : "This platform cannot provide App Attest, so remote services lose a key Apple trust signal.",
            recommendation: isSupported
                ? "Keep remote discovery, PIR, and relay paths behind App Attest verification."
                : "Treat server features as degraded until App Attest-backed validation is available.",
            systemImage: "checkmark.shield.fill",
            state: isSupported ? .ready : .attention
        )
        #else
        return AppleSecurityCapability(
            id: .appAttestation,
            title: "App Attestation",
            shortValue: "Unavailable",
            detail: "DeviceCheck is unavailable on this platform, so App Attest cannot participate in the trust model.",
            recommendation: "Reserve server-sensitive roles for platforms with App Attest support.",
            systemImage: "checkmark.shield.fill",
            state: .limited
        )
        #endif
    }

    private func nearbyTrustCapability(for role: DeviceRole) -> AppleSecurityCapability {
        #if os(macOS)
        return AppleSecurityCapability(
            id: .nearbyTrust,
            title: "Nearby Trust",
            shortValue: "Attested Network",
            detail: "Mac peers rely on attested local-network trust sessions. Nearby Interaction is unavailable on macOS.",
            recommendation: "Keep Mac peers in proof and diagnostics roles, not the canonical co-presence lane.",
            systemImage: "macbook.and.iphone",
            state: .attention
        )
        #elseif os(iOS)
        let preciseDistanceSupported = NISession.deviceCapabilities.supportsPreciseDistanceMeasurement

        return AppleSecurityCapability(
            id: .nearbyTrust,
            title: "Nearby Trust",
            shortValue: preciseDistanceSupported ? "Precision Nearby" : "Attested Local",
            detail: preciseDistanceSupported
                ? "\(role.isAuthority ? "This device" : "This peer") can support precision Nearby Interaction for short-lived co-presence trust."
                : "Nearby precision is unavailable, so peer trust falls back to attested local transport without spatial evidence.",
            recommendation: preciseDistanceSupported
                ? "Use precision nearby trust for vault and recovery approval whenever a peer is physically present."
                : "Keep the trust window short and seal sessions aggressively when spatial evidence is unavailable.",
            systemImage: preciseDistanceSupported ? "dot.radiowaves.left.and.right" : "wave.3.right",
            state: preciseDistanceSupported ? .ready : .attention
        )
        #else
        return AppleSecurityCapability(
            id: .nearbyTrust,
            title: "Nearby Trust",
            shortValue: "Unavailable",
            detail: "Nearby Interaction is unavailable on this platform.",
            recommendation: "Do not rely on this platform for the primary physical trust role.",
            systemImage: "wave.3.right",
            state: .limited
        )
        #endif
    }

    private func localStateCapability() -> AppleSecurityCapability {
        do {
            let containerURL = try backupManager.walletContainerURL()
            let values = try containerURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
            let isExcludedFromBackup = values.isExcludedFromBackup == true

            #if canImport(UIKit)
            let attributes = try FileManager.default.attributesOfItem(atPath: containerURL.path)
            let hasFileProtection = attributes[.protectionKey] != nil
            #else
            let hasFileProtection = true
            #endif

            let state: AppleSecurityCapabilityState
            if isExcludedFromBackup && hasFileProtection {
                state = .ready
            } else if isExcludedFromBackup || hasFileProtection {
                state = .attention
            } else {
                state = .limited
            }

            let shortValue: String
            if isExcludedFromBackup && hasFileProtection {
                shortValue = "Sealed On Device"
            } else if isExcludedFromBackup {
                shortValue = "Backup Excluded"
            } else {
                shortValue = "Needs Hardening"
            }

            let detail: String
            if isExcludedFromBackup && hasFileProtection {
                detail = "Wallet state is sealed before disk persistence, stored in an app-support container excluded from backups, and protected by the filesystem."
            } else if isExcludedFromBackup {
                detail = "Wallet state is excluded from backups, but full local file protection could not be confirmed."
            } else {
                detail = "The wallet state container is not fully hardened against backup or local exposure."
            }

            return AppleSecurityCapability(
                id: .localState,
                title: "Local State Boundary",
                shortValue: shortValue,
                detail: detail,
                recommendation: state == .ready
                    ? "Keep recovery and vault state device-bound and short-lived."
                    : "Harden the local state container before treating this build as a shipping authority surface.",
                systemImage: "externaldrive.fill.badge.icloud",
                state: state
            )
        } catch {
            return AppleSecurityCapability(
                id: .localState,
                title: "Local State Boundary",
                shortValue: "Inspection Failed",
                detail: error.localizedDescription,
                recommendation: "Repair local-state hardening before trusting this device with recovery material.",
                systemImage: "externaldrive.badge.exclamationmark",
                state: .limited
            )
        }
    }

    private func privacyBoundaryCapability(isScreenCaptureActive: Bool) -> AppleSecurityCapability {
        AppleSecurityCapability(
            id: .privacyBoundary,
            title: "Privacy Boundary",
            shortValue: isScreenCaptureActive ? "Redaction Live" : "Monitor Armed",
            detail: isScreenCaptureActive
                ? "A capture boundary is active. Sensitive UI is redacted and vault memory should remain sealed."
                : "Capture monitoring and protected-data transitions are armed so privileged state clears quickly when the boundary becomes unsafe.",
            recommendation: isScreenCaptureActive
                ? "Finish the capture session before attempting privileged wallet work."
                : "Keep sensitive flows brief so redaction remains the exception, not the habit.",
            systemImage: isScreenCaptureActive ? "eye.slash.circle.fill" : "record.circle",
            state: isScreenCaptureActive ? .attention : .ready
        )
    }

    private func preferredTrustTransport(for role: DeviceRole) -> String {
        switch role {
        case .authorityPhone, .recoveryPad:
            #if os(iOS)
            if NISession.deviceCapabilities.supportsPreciseDistanceMeasurement {
                return "Nearby Interaction + Network.framework"
            }
            return "Network.framework"
            #else
            return "Network.framework"
            #endif
        case .recoveryMac:
            return "Network.framework"
        }
    }

    private func biometryTypeLabel(_ type: LABiometryType) -> String {
        switch type {
        case .none:
            return "Biometry"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        #if os(iOS)
        case .opticID:
            return "Optic ID"
        #endif
        @unknown default:
            return "Biometry"
        }
    }
}
