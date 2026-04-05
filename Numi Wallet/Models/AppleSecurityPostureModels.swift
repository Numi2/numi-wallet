import Foundation

enum AppleSecurityCapabilityState: String, Sendable {
    case ready
    case attention
    case limited

    var label: String {
        switch self {
        case .ready:
            return "Ready"
        case .attention:
            return "Attention"
        case .limited:
            return "Limited"
        }
    }

    var readinessWeight: Double {
        switch self {
        case .ready:
            return 1
        case .attention:
            return 0.64
        case .limited:
            return 0.28
        }
    }
}

enum AppleSecurityCapabilityID: String, Identifiable, Sendable {
    case postQuantumRoot
    case postQuantumTransport
    case ownerAuthentication
    case appAttestation
    case nearbyTrust
    case localState
    case privacyBoundary

    var id: String { rawValue }
}

struct AppleSecurityCapability: Identifiable, Sendable {
    let id: AppleSecurityCapabilityID
    let title: String
    let shortValue: String
    let detail: String
    let recommendation: String
    let systemImage: String
    let state: AppleSecurityCapabilityState
}

struct AppleSecurityPosture: Sendable {
    let assessedAt: Date
    let headline: String
    let summary: String
    let preferredTrustTransport: String
    let capabilities: [AppleSecurityCapability]

    static let placeholder = AppleSecurityPosture(
        assessedAt: .distantPast,
        headline: "Scanning Apple trust fabric",
        summary: "Capability telemetry has not been collected yet.",
        preferredTrustTransport: "Scanning",
        capabilities: []
    )

    var readiness: Double {
        guard !capabilities.isEmpty else { return 0 }
        let total = capabilities.map { $0.state.readinessWeight }.reduce(0, +)
        return total / Double(capabilities.count)
    }

    var readyCount: Int {
        capabilities.filter { $0.state == .ready }.count
    }

    var attentionCount: Int {
        capabilities.filter { $0.state == .attention }.count
    }

    var limitedCount: Int {
        capabilities.filter { $0.state == .limited }.count
    }

    var shortDescriptor: String {
        guard !capabilities.isEmpty else { return "Trust fabric pending" }
        return "\(readyCount)/\(capabilities.count) trust anchors ready"
    }

    var primaryRecommendation: String {
        capabilities.first(where: { $0.state != .ready })?.recommendation
            ?? "Core Apple trust anchors are in a strong state. Keep privileged work brief and local."
    }
}
