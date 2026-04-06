import CryptoKit
import Foundation
import Network

#if canImport(NearbyInteraction)
import NearbyInteraction
#endif

actor PairingChannel {
    private struct LocalSessionBindingMaterial: Codable {
        let hello: UnsignedLocalPairingHello
        let responderInvitation: PairingInvitation
        let responderInvitationSignature: Data
        let sessionID: UUID
        let expiresAt: Date
    }

    private let keyManager: SecureEnclaveKeyManager
    private let appAttest: AppAttestProvider?
    private var bootstrapKeys: [UUID: XWingMLKEM768X25519.PrivateKey] = [:]
    private var sessionSecrets: [UUID: Data] = [:]

    init(keyManager: SecureEnclaveKeyManager, appAttest: AppAttestProvider? = nil) {
        self.keyManager = keyManager
        self.appAttest = appAttest
    }

    func makeInvitation(
        localDeviceID: String = "numi.local-device",
        localRole: DeviceRole = .authorityPhone,
        capabilities: [PeerSessionCapability]? = nil,
        port: UInt16 = 4646
    ) async throws -> PairingInvitation {
        let bootstrapKey = try XWingMLKEM768X25519.PrivateKey()
        let invitationID = UUID()
        bootstrapKeys[invitationID] = bootstrapKey
        return PairingInvitation(
            id: invitationID,
            host: "numi.local",
            port: port,
            deviceID: localDeviceID,
            deviceRole: localRole,
            bootstrapCode: String((0..<6).map { _ in Int.random(in: 0...9) }.map(String.init).joined()),
            transport: .networkFramework,
            supportsNearbyInteraction: supportsNearbyInteraction(),
            capabilities: PeerSessionCapability.canonicalize(capabilities ?? PeerSessionCapability.defaults(for: localRole)),
            verifyingKey: try await keyManager.ensurePeerIdentityPublicKey(),
            sessionBootstrapPublicKey: bootstrapKey.publicKey.rawRepresentation,
            issuedAt: Date()
        )
    }

    func attestedTranscript(for invitation: PairingInvitation) async throws -> Data {
        try await signInvitation(invitation)
    }

    func signInvitation(_ invitation: PairingInvitation) async throws -> Data {
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

    func makeHandshakeHello(
        localInvitation: PairingInvitation,
        peerName: String
    ) async throws -> LocalPairingHello {
        let invitationSignature = try await signInvitation(localInvitation)
        let unsigned = UnsignedLocalPairingHello(
            invitation: localInvitation,
            invitationSignature: invitationSignature,
            peerName: peerName,
            challenge: randomData(length: 32),
            appAttestation: try await makePairingAttestation(for: Data(localInvitation.id.uuidString.utf8)),
            sentAt: Date()
        )
        let payload = try JSONEncoder().encode(unsigned)
        let signature = try await keyManager.signPeerPayload(payload)
        return LocalPairingHello(
            invitation: unsigned.invitation,
            invitationSignature: unsigned.invitationSignature,
            peerName: unsigned.peerName,
            challenge: unsigned.challenge,
            appAttestation: unsigned.appAttestation,
            sentAt: unsigned.sentAt,
            signature: signature
        )
    }

    func verify(_ hello: LocalPairingHello) async throws -> Bool {
        guard hello.sentAt <= Date().addingTimeInterval(30),
              !hello.challenge.isEmpty else {
            return false
        }
        let invitationPayload = try JSONEncoder().encode(hello.invitation)
        guard try await keyManager.verifyPeerSignature(
            signature: hello.invitationSignature,
            payload: invitationPayload,
            publicKey: hello.invitation.verifyingKey
        ) else {
            return false
        }

        let payload = try JSONEncoder().encode(hello.unsigned())
        return try await keyManager.verifyPeerSignature(
            signature: hello.signature,
            payload: payload,
            publicKey: hello.invitation.verifyingKey
        )
    }

    func respond(
        to hello: LocalPairingHello,
        localInvitation: PairingInvitation,
        peerName: String,
        ttl: TimeInterval = 5 * 60
    ) async throws -> LocalPairingHelloAck {
        guard try await verify(hello) else {
            throw WalletError.invalidLocalPeerSession
        }

        let responderInvitationSignature = try await signInvitation(localInvitation)
        let sessionID = UUID()
        let establishedAt = Date()
        let expiresAt = establishedAt.addingTimeInterval(ttl)
        let sessionSecret = randomData(length: 32)
        let encryptedSessionSecret = try sealSessionSecret(
            sessionSecret,
            to: hello.invitation,
            sessionID: sessionID,
            expiresAt: expiresAt,
            hello: hello,
            responderInvitation: localInvitation,
            responderInvitationSignature: responderInvitationSignature
        )
        let sessionBindingDigest = try makeLocalSessionBindingDigest(
            hello: hello,
            responderInvitation: localInvitation,
            responderInvitationSignature: responderInvitationSignature,
            sessionID: sessionID,
            expiresAt: expiresAt
        )
        sessionSecrets[sessionID] = sessionSecret
        let unsigned = UnsignedLocalPairingHelloAck(
            responderInvitation: localInvitation,
            responderInvitationSignature: responderInvitationSignature,
            responderPeerName: peerName,
            sessionID: sessionID,
            establishedAt: establishedAt,
            expiresAt: expiresAt,
            challengeDigest: Data(SHA256.hash(data: hello.challenge)),
            sessionBindingDigest: sessionBindingDigest,
            encryptedSessionSecret: encryptedSessionSecret,
            appAttestation: try await makePairingAttestation(for: sessionBindingDigest)
        )
        let payload = try JSONEncoder().encode(unsigned)
        let signature = try await keyManager.signPeerPayload(payload)
        return LocalPairingHelloAck(
            responderInvitation: unsigned.responderInvitation,
            responderInvitationSignature: unsigned.responderInvitationSignature,
            responderPeerName: unsigned.responderPeerName,
            sessionID: unsigned.sessionID,
            establishedAt: unsigned.establishedAt,
            expiresAt: unsigned.expiresAt,
            challengeDigest: unsigned.challengeDigest,
            sessionBindingDigest: unsigned.sessionBindingDigest,
            encryptedSessionSecret: unsigned.encryptedSessionSecret,
            appAttestation: unsigned.appAttestation,
            signature: signature
        )
    }

    func verify(_ ack: LocalPairingHelloAck, for hello: LocalPairingHello) async throws -> Bool {
        guard try await verify(hello),
              ack.establishedAt <= ack.expiresAt,
              ack.challengeDigest == Data(SHA256.hash(data: hello.challenge)) else {
            return false
        }

        let responderInvitationPayload = try JSONEncoder().encode(ack.responderInvitation)
        guard try await keyManager.verifyPeerSignature(
            signature: ack.responderInvitationSignature,
            payload: responderInvitationPayload,
            publicKey: ack.responderInvitation.verifyingKey
        ) else {
            return false
        }

        let expectedBindingDigest = try makeLocalSessionBindingDigest(
            hello: hello,
            responderInvitation: ack.responderInvitation,
            responderInvitationSignature: ack.responderInvitationSignature,
            sessionID: ack.sessionID,
            expiresAt: ack.expiresAt
        )
        guard expectedBindingDigest == ack.sessionBindingDigest else {
            return false
        }

        let payload = try JSONEncoder().encode(ack.unsigned())
        return try await keyManager.verifyPeerSignature(
            signature: ack.signature,
            payload: payload,
            publicKey: ack.responderInvitation.verifyingKey
        )
    }

    func establishLocalSession(
        from ack: LocalPairingHelloAck,
        for hello: LocalPairingHello
    ) async throws -> AuthenticatedLocalPeerSession {
        guard try await verify(ack, for: hello) else {
            throw WalletError.invalidLocalPeerSession
        }

        let sessionSecret = try openSessionSecret(
            ack.encryptedSessionSecret,
            for: hello.invitation.id,
            bindingDigest: ack.sessionBindingDigest
        )
        let sessionSecretDigest = Data(SHA256.hash(data: sessionSecret))
        sessionSecrets[ack.sessionID] = sessionSecret
        return AuthenticatedLocalPeerSession(
            id: ack.sessionID,
            localInvitationID: hello.invitation.id,
            remoteInvitationID: ack.responderInvitation.id,
            localDeviceID: hello.invitation.deviceID,
            remoteDeviceID: ack.responderInvitation.deviceID,
            localRole: hello.invitation.deviceRole,
            remoteRole: ack.responderInvitation.deviceRole,
            remotePeerName: ack.responderPeerName,
            remoteVerifyingKey: ack.responderInvitation.verifyingKey,
            transport: ack.responderInvitation.transport,
            supportsNearbyInteraction: ack.responderInvitation.supportsNearbyInteraction,
            remoteCapabilities: ack.responderInvitation.capabilities,
            transcriptFingerprint: ack.sessionBindingDigest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description,
            sessionBindingDigest: ack.sessionBindingDigest,
            sessionSecretDigest: sessionSecretDigest,
            localAppAttested: hello.appAttestation != nil,
            remoteAppAttested: ack.appAttestation != nil,
            establishedAt: ack.establishedAt,
            expiresAt: ack.expiresAt,
            proximityEvidence: .authenticatedLocalChannel,
            trustLevel: .attestedLocal,
            nearbyVerification: nil
        )
    }

    func makeSessionSeal(for session: AuthenticatedLocalPeerSession) async throws -> LocalPairingSessionSeal {
        guard let sessionSecret = sessionSecrets[session.id] else {
            throw WalletError.invalidLocalPeerSession
        }
        let unsigned = UnsignedLocalPairingSessionSeal(
            sessionID: session.id,
            sessionBindingDigest: session.sessionBindingDigest,
            sessionSecretDigest: Data(SHA256.hash(data: sessionSecret)),
            confirmedAt: Date()
        )
        let payload = try JSONEncoder().encode(unsigned)
        let signature = try await keyManager.signPeerPayload(payload)
        return LocalPairingSessionSeal(
            sessionID: unsigned.sessionID,
            sessionBindingDigest: unsigned.sessionBindingDigest,
            sessionSecretDigest: unsigned.sessionSecretDigest,
            confirmedAt: unsigned.confirmedAt,
            signature: signature
        )
    }

    func verify(
        _ seal: LocalPairingSessionSeal,
        for hello: LocalPairingHello,
        ack: LocalPairingHelloAck
    ) async throws -> Bool {
        guard seal.sessionID == ack.sessionID,
              seal.sessionBindingDigest == ack.sessionBindingDigest,
              seal.confirmedAt >= ack.establishedAt,
              seal.confirmedAt <= ack.expiresAt,
              let sessionSecret = sessionSecrets[seal.sessionID] else {
            return false
        }

        let expectedSecretDigest = Data(SHA256.hash(data: sessionSecret))
        guard seal.sessionSecretDigest == expectedSecretDigest else {
            return false
        }

        let payload = try JSONEncoder().encode(seal.unsigned())
        return try await keyManager.verifyPeerSignature(
            signature: seal.signature,
            payload: payload,
            publicKey: hello.invitation.verifyingKey
        )
    }

    func forgetLocalSession(id: UUID) {
        sessionSecrets[id] = nil
    }

    func sessionSecretDigest(for sessionID: UUID) throws -> Data {
        guard let sessionSecret = sessionSecrets[sessionID] else {
            throw WalletError.invalidLocalPeerSession
        }
        return Data(SHA256.hash(data: sessionSecret))
    }

    func sealSessionPayload(
        _ payload: Data,
        for sessionID: UUID,
        authenticating authenticatedData: Data
    ) throws -> Data {
        guard let sessionSecret = sessionSecrets[sessionID] else {
            throw WalletError.invalidLocalPeerSession
        }
        let key = SymmetricKey(data: sessionSecret)
        let sealed = try AES.GCM.seal(payload, using: key, authenticating: authenticatedData)
        guard let combined = sealed.combined else {
            throw WalletError.invalidLocalPeerSession
        }
        return combined
    }

    func openSessionPayload(
        _ sealedPayload: Data,
        for sessionID: UUID,
        authenticating authenticatedData: Data
    ) throws -> Data {
        guard let sessionSecret = sessionSecrets[sessionID] else {
            throw WalletError.invalidLocalPeerSession
        }
        let key = SymmetricKey(data: sessionSecret)
        let sealedBox = try AES.GCM.SealedBox(combined: sealedPayload)
        return try AES.GCM.open(sealedBox, using: key, authenticating: authenticatedData)
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

    private func makePairingAttestation(for challenge: some DataProtocol) async throws -> PairingAttestation? {
        let material = Data(challenge)
        return try await appAttest?.assertion(for: material).map {
            PairingAttestation(
                keyID: $0.keyID,
                signature: $0.assertion,
                clientDataHash: $0.clientDataHash
            )
        }
    }

    private func makeLocalSessionBindingDigest(
        hello: LocalPairingHello,
        responderInvitation: PairingInvitation,
        responderInvitationSignature: Data,
        sessionID: UUID,
        expiresAt: Date
    ) throws -> Data {
        let material = LocalSessionBindingMaterial(
            hello: hello.unsigned(),
            responderInvitation: responderInvitation,
            responderInvitationSignature: responderInvitationSignature,
            sessionID: sessionID,
            expiresAt: expiresAt
        )
        return Data(SHA256.hash(data: try JSONEncoder().encode(material)))
    }

    private func sealSessionSecret(
        _ sessionSecret: Data,
        to invitation: PairingInvitation,
        sessionID: UUID,
        expiresAt: Date,
        hello: LocalPairingHello,
        responderInvitation: PairingInvitation,
        responderInvitationSignature: Data
    ) throws -> LocalPairingCiphertext {
        let bindingDigest = try makeLocalSessionBindingDigest(
            hello: hello,
            responderInvitation: responderInvitation,
            responderInvitationSignature: responderInvitationSignature,
            sessionID: sessionID,
            expiresAt: expiresAt
        )
        let recipientKey = try XWingMLKEM768X25519.PublicKey(rawRepresentation: invitation.sessionBootstrapPublicKey)
        var sender = try HPKE.Sender(
            recipientKey: recipientKey,
            ciphersuite: .XWingMLKEM768X25519_SHA256_AES_GCM_256,
            info: bindingDigest
        )
        let ciphertext = try sender.seal(sessionSecret, authenticating: bindingDigest)
        return LocalPairingCiphertext(
            encapsulatedKey: sender.encapsulatedKey,
            ciphertext: ciphertext
        )
    }

    private func openSessionSecret(
        _ ciphertext: LocalPairingCiphertext,
        for invitationID: UUID,
        bindingDigest: Data
    ) throws -> Data {
        guard let bootstrapKey = bootstrapKeys[invitationID] else {
            throw WalletError.invalidLocalPeerSession
        }
        var recipient = try HPKE.Recipient(
            privateKey: bootstrapKey,
            ciphersuite: .XWingMLKEM768X25519_SHA256_AES_GCM_256,
            info: bindingDigest,
            encapsulatedKey: ciphertext.encapsulatedKey
        )
        return try recipient.open(ciphertext.ciphertext, authenticating: bindingDigest)
    }

    private func randomData(length: Int) -> Data {
        Data((0..<length).map { _ in UInt8.random(in: .min ... .max) })
    }
}
