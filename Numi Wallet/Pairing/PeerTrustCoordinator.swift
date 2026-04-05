import Foundation

actor PeerTrustCoordinator {
    private let pairingChannel: PairingChannel
    private let localDeviceID: String
    private var activeSession: PeerTrustSession?

    init(pairingChannel: PairingChannel, localDeviceID: String) {
        self.pairingChannel = pairingChannel
        self.localDeviceID = localDeviceID
    }

    func establishSession(with peerKind: PeerKind, ttl: TimeInterval = 5 * 60) async throws -> PeerTrustSession {
        let invitation = try await pairingChannel.makeInvitation()
        let peerRole: DeviceRole = switch peerKind {
        case .mac:
            .recoveryMac
        case .pad:
            .recoveryPad
        }
        let transcript = try await pairingChannel.makeSessionTranscript(
            for: invitation,
            peerDeviceID: peerDeviceID(for: peerKind),
            peerRole: peerRole,
            ttl: ttl
        )

        guard try await pairingChannel.verify(transcript, for: invitation) else {
            throw WalletError.invalidPeerTrustSession
        }

        let session = PeerTrustSession(
            id: transcript.sessionID,
            peerName: peerName(for: peerKind),
            peerKind: peerKind,
            peerRole: peerRole,
            peerDeviceID: transcript.peerDeviceID,
            invitationID: invitation.id,
            transcriptFingerprint: transcript.fingerprint,
            transport: invitation.transport,
            trustLevel: invitation.transport == .nearbyInteraction && peerKind == .pad ? .nearbyVerified : .attestedLocal,
            appAttested: transcript.appAttestation != nil,
            establishedAt: transcript.createdAt,
            expiresAt: transcript.expiresAt
        )
        activeSession = session
        return session
    }

    func currentSession() -> PeerTrustSession? {
        guard let activeSession else { return nil }
        guard activeSession.isActive else {
            self.activeSession = nil
            return nil
        }
        return activeSession
    }

    func clearSession() {
        activeSession = nil
    }

    private func peerName(for kind: PeerKind) -> String {
        switch kind {
        case .mac:
            return "Mac Sovereign Peer"
        case .pad:
            return "iPad Recovery Peer"
        }
    }

    private func peerDeviceID(for kind: PeerKind) -> String {
        switch kind {
        case .mac:
            return "\(localDeviceID)-mac-peer"
        case .pad:
            return "\(localDeviceID)-pad-peer"
        }
    }
}
