import Foundation

actor PeerTrustCoordinator {
    private let pairingChannel: PairingChannel
    private var activeSession: PeerTrustSession?

    init(pairingChannel: PairingChannel) {
        self.pairingChannel = pairingChannel
    }

    func establishSession(from localSession: AuthenticatedLocalPeerSession) async throws -> PeerTrustSession {
        guard localSession.isActive,
              let peerKind = localSession.remotePeerKind else {
            throw WalletError.invalidPeerTrustSession
        }

        let session = PeerTrustSession(
            id: localSession.id,
            peerName: localSession.remotePeerName,
            peerKind: peerKind,
            peerRole: localSession.remoteRole,
            peerDeviceID: localSession.remoteDeviceID,
            peerVerifyingKey: localSession.remoteVerifyingKey,
            invitationID: localSession.remoteInvitationID,
            transcriptFingerprint: localSession.transcriptFingerprint,
            transport: localSession.transport,
            capabilities: localSession.remoteCapabilities,
            proximityEvidence: localSession.proximityEvidence,
            trustLevel: localSession.trustLevel,
            nearbyVerification: localSession.nearbyVerification,
            appAttested: localSession.remoteAppAttested,
            establishedAt: localSession.establishedAt,
            expiresAt: localSession.expiresAt
        )
        activeSession = session
        return session
    }

    func issuePresenceAssertion(ttl: TimeInterval = 90) async throws -> PeerPresenceAssertion {
        guard let session = currentSession() else {
            throw WalletError.peerPresenceRequired
        }
        return try await pairingChannel.makePresenceAssertion(for: session, ttl: ttl)
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
}
