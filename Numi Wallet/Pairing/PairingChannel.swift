import Foundation
import Network

#if canImport(NearbyInteraction)
import NearbyInteraction
#endif

actor PairingChannel {
    private let keyManager: SecureEnclaveKeyManager
    private let appAttest: AppAttestProvider?

    init(keyManager: SecureEnclaveKeyManager, appAttest: AppAttestProvider? = nil) {
        self.keyManager = keyManager
        self.appAttest = appAttest
    }

    func makeInvitation(port: UInt16 = 4646) async throws -> PairingInvitation {
        PairingInvitation(
            id: UUID(),
            host: "numi.local",
            port: port,
            bootstrapCode: String((0..<6).map { _ in Int.random(in: 0...9) }.map(String.init).joined()),
            transport: supportsNearbyInteraction() ? .nearbyInteraction : .networkFramework,
            verifyingKey: try await keyManager.ensurePeerIdentityPublicKey(),
            issuedAt: Date()
        )
    }

    func attestedTranscript(for invitation: PairingInvitation) async throws -> Data {
        let payload = try JSONEncoder().encode(invitation)
        return try await keyManager.signPeerPayload(payload)
    }

    func verify(invitation: PairingInvitation, signature: Data) async throws -> Bool {
        let payload = try JSONEncoder().encode(invitation)
        return try await keyManager.verifyPeerSignature(
            signature: signature,
            payload: payload,
            publicKey: invitation.verifyingKey
        )
    }

    func makeSessionTranscript(
        for invitation: PairingInvitation,
        peerDeviceID: String,
        peerRole: DeviceRole,
        ttl: TimeInterval = 5 * 60
    ) async throws -> PairingSessionTranscript {
        let challenge = randomData(length: 32)
        let invitationPayload = try JSONEncoder().encode(invitation)
        let invitationSignature = try await keyManager.signPeerPayload(invitationPayload)
        let attestation = try await appAttest?.assertion(for: challenge)

        return PairingSessionTranscript(
            sessionID: UUID(),
            invitationID: invitation.id,
            peerDeviceID: peerDeviceID,
            peerRole: peerRole,
            transport: invitation.transport,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(ttl),
            challenge: challenge,
            verifierPublicKey: invitation.verifyingKey,
            invitationSignature: invitationSignature,
            appAttestation: attestation.map {
                PairingAttestation(
                    keyID: $0.keyID,
                    signature: $0.assertion,
                    clientDataHash: $0.clientDataHash
                )
            }
        )
    }

    func verify(_ transcript: PairingSessionTranscript, for invitation: PairingInvitation) async throws -> Bool {
        guard transcript.invitationID == invitation.id,
              transcript.transport == invitation.transport,
              transcript.verifierPublicKey == invitation.verifyingKey,
              transcript.expiresAt >= Date() else {
            return false
        }

        let invitationPayload = try JSONEncoder().encode(invitation)
        return try await keyManager.verifyPeerSignature(
            signature: transcript.invitationSignature,
            payload: invitationPayload,
            publicKey: transcript.verifierPublicKey
        )
    }

    func localNetworkParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true
        return parameters
    }

    func supportsNearbyInteraction() -> Bool {
        #if canImport(NearbyInteraction) && !os(macOS)
        return NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
        #else
        return false
        #endif
    }

    private func randomData(length: Int) -> Data {
        Data((0..<length).map { _ in UInt8.random(in: .min ... .max) })
    }
}
