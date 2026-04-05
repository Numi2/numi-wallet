import Foundation
import LocalAuthentication

struct LocalAuthenticationClient: Sendable {
    func authenticateBiometric(reason: String) async throws -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Device Passcode"
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error, error.code == LAError.userCancel.rawValue {
                throw WalletError.userCancelled
            }
            throw WalletError.biometricAuthenticationUnavailable
        }

        let success = try await evaluate(
            context: context,
            policy: .deviceOwnerAuthenticationWithBiometrics,
            reason: reason
        )
        guard success else { throw WalletError.userCancelled }
        return context
    }

    func authenticateDeviceOwner(reason: String) async throws -> LAContext {
        let context = LAContext()
        let success = try await evaluate(
            context: context,
            policy: .deviceOwnerAuthentication,
            reason: reason
        )
        guard success else { throw WalletError.userCancelled }
        return context
    }

    private func evaluate(context: LAContext, policy: LAPolicy, reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == LAError.errorDomain, nsError.code == LAError.userCancel.rawValue {
                        continuation.resume(throwing: WalletError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }
}
