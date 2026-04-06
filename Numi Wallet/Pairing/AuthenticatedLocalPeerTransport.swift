import CryptoKit
import Foundation
import Network

#if canImport(NearbyInteraction) && !os(macOS)
import NearbyInteraction
#endif

#if canImport(NearbyInteraction) && !os(macOS)
@MainActor
private final class NearbyInteractionVerifier: NSObject, NISessionDelegate {
    private static let requiredDistanceMeters: Float = 3.0

    private let session = NISession()
    private var activeConfiguration: NINearbyPeerConfiguration?
    private var continuation: CheckedContinuation<NearbyPeerVerification, Error>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = .main
    }

    func localDiscoveryTokenData() throws -> Data {
        guard let discoveryToken = session.discoveryToken else {
            throw WalletError.localPeerTransportUnavailable
        }
        return try NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true)
    }

    func verify(remoteTokenData: Data, timeout: TimeInterval = 12) async throws -> NearbyPeerVerification {
        guard continuation == nil else {
            throw WalletError.invalidLocalPeerSession
        }
        guard let remoteToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: remoteTokenData) else {
            throw WalletError.invalidLocalPeerSession
        }

        let configuration = NINearbyPeerConfiguration(peerToken: remoteToken)
        if #available(iOS 17.0, *),
           NISession.deviceCapabilities.supportsExtendedDistanceMeasurement,
           remoteToken.deviceCapabilities.supportsExtendedDistanceMeasurement {
            configuration.isExtendedDistanceMeasurementEnabled = true
        }

        activeConfiguration = configuration
        session.run(configuration)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.timeoutTask = Task { [weak self] in
                let interval = UInt64(timeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
                self?.finish(with: .failure(WalletError.localPeerTransportUnavailable))
            }
        }
    }

    func invalidate() {
        timeoutTask?.cancel()
        timeoutTask = nil
        activeConfiguration = nil
        continuation = nil
        session.invalidate()
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let nearbyObject = nearbyObjects.first,
              let distance = nearbyObject.distance,
              distance.isFinite,
              distance > 0,
              distance <= Self.requiredDistanceMeters else {
            return
        }

        let verification = NearbyPeerVerification(
            verifiedAt: Date(),
            distanceMeters: Double(distance),
            directionAvailable: nearbyObject.direction != nil
        )
        Task {
            finish(with: .success(verification))
        }
    }

    func sessionWasSuspended(_ session: NISession) {}

    func sessionSuspensionEnded(_ session: NISession) {
        guard let activeConfiguration else { return }
        session.run(activeConfiguration)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        Task {
            finish(with: .failure(error))
        }
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task {
            finish(with: .failure(WalletError.localPeerTransportUnavailable))
        }
    }

    private func finish(with result: Result<NearbyPeerVerification, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        activeConfiguration = nil
        guard let continuation else { return }
        self.continuation = nil
        switch result {
        case .success(let verification):
            continuation.resume(returning: verification)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
#endif

actor AuthenticatedLocalPeerTransport {
    private final class ResumeGate: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false

        func resume(_ action: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !resumed else { return }
            resumed = true
            action()
        }
    }

    private struct HostedIdentity {
        let localDeviceID: String
        let localRole: DeviceRole
        let peerName: String
        let invitation: PairingInvitation
        let serviceName: String
    }

    private struct ResolvedPeerEndpoint {
        let publicPeer: DiscoveredLocalPeerEndpoint
        let endpoint: NWEndpoint
    }

    private enum WireKind: String, Codable {
        case hello
        case helloAck
        case sessionSeal
        case recoveryTransfer
        case nearbyToken
    }

    private struct WireEnvelope: Codable {
        let kind: WireKind
        let payload: Data
    }

    private static let serviceType = "_numipeer._tcp"

    private let pairingChannel: PairingChannel
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "numi.local-peer-transport")

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var hostedIdentity: HostedIdentity?
    private var discoveredPeers: [String: ResolvedPeerEndpoint] = [:]
    private var activeSessions: [UUID: AuthenticatedLocalPeerSession] = [:]
    private var sessionConnections: [UUID: NWConnection] = [:]
    private var receiveTasks: [UUID: Task<Void, Never>] = [:]
    private var nearbyVerificationTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingNearbyTokens: [UUID: Data] = [:]
    private var pendingIncomingTransfers: [PendingLocalRecoveryTransfer] = []
    private var observers: [UUID: AsyncStream<LocalPeerTransportSnapshot>.Continuation] = [:]

    init(pairingChannel: PairingChannel) {
        self.pairingChannel = pairingChannel
    }

    func updates() -> AsyncStream<LocalPeerTransportSnapshot> {
        let observerID = UUID()
        return AsyncStream { continuation in
            Task {
                self.addObserver(observerID, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.removeObserver(observerID)
                }
            }
        }
    }

    func activate(
        localDeviceID: String,
        localRole: DeviceRole,
        peerName: String
    ) async throws -> LocalPeerTransportSnapshot {
        if hostedIdentity != nil {
            return snapshot()
        }

        let parameters = await pairingChannel.localNetworkParameters()
        let listener = try NWListener(using: parameters, on: .any)
        let serviceName = "numi-\(localRole.rawValue)-\(String(localDeviceID.prefix(6)))"
        listener.service = NWListener.Service(name: serviceName, type: Self.serviceType)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task {
                await self.handleIncomingConnection(connection)
            }
        }

        self.listener = listener
        try await startListener(listener)
        guard let port = listener.port else {
            throw WalletError.localPeerTransportUnavailable
        }

        let invitation = try await pairingChannel.makeInvitation(
            localDeviceID: localDeviceID,
            localRole: localRole,
            capabilities: PeerSessionCapability.defaults(for: localRole),
            port: port.rawValue
        )
        hostedIdentity = HostedIdentity(
            localDeviceID: localDeviceID,
            localRole: localRole,
            peerName: peerName,
            invitation: invitation,
            serviceName: serviceName
        )

        let browser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: parameters
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task {
                await self.handleBrowseResults(results)
            }
        }
        browser.stateUpdateHandler = { _ in }
        browser.start(queue: queue)
        self.browser = browser

        let currentSnapshot = snapshot()
        notifyObservers()
        return currentSnapshot
    }

    func currentSnapshot() -> LocalPeerTransportSnapshot {
        snapshot()
    }

    func activeSessionsSnapshot() -> [AuthenticatedLocalPeerSession] {
        activeSessions.values
            .filter(\.isActive)
            .sorted {
                if $0.trustLevel == $1.trustLevel {
                    return $0.establishedAt > $1.establishedAt
                }
                return trustRank(for: $0.trustLevel) > trustRank(for: $1.trustLevel)
            }
    }

    func consumeNextPendingRecoveryTransfer() -> PendingLocalRecoveryTransfer? {
        guard !pendingIncomingTransfers.isEmpty else { return nil }
        let transfer = pendingIncomingTransfers.removeFirst()
        notifyObservers()
        return transfer
    }

    func peekNextPendingRecoveryTransfer() -> PendingLocalRecoveryTransfer? {
        pendingIncomingTransfers.first
    }

    func consumePendingRecoveryTransfer(id: UUID) -> PendingLocalRecoveryTransfer? {
        guard let index = pendingIncomingTransfers.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let transfer = pendingIncomingTransfers.remove(at: index)
        notifyObservers()
        return transfer
    }

    func discardPendingRecoveryTransfer(id: UUID) {
        guard let index = pendingIncomingTransfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        pendingIncomingTransfers.remove(at: index)
        notifyObservers()
    }

    func establishSession(
        preferredPeerKind: PeerKind?,
        preferredRemoteRole: DeviceRole? = nil
    ) async throws -> AuthenticatedLocalPeerSession {
        guard let hostedIdentity else {
            throw WalletError.localPeerTransportUnavailable
        }

        if let existingSession = activeSessions.values
            .filter(\.isActive)
            .sorted(by: {
                if $0.trustLevel == $1.trustLevel {
                    return $0.establishedAt > $1.establishedAt
                }
                return trustRank(for: $0.trustLevel) > trustRank(for: $1.trustLevel)
            })
            .first(where: { session in
                let peerKindMatches = preferredPeerKind == nil || session.remotePeerKind == preferredPeerKind
                let remoteRoleMatches = preferredRemoteRole == nil || session.remoteRole == preferredRemoteRole
                return peerKindMatches && remoteRoleMatches
            }) {
            return existingSession
        }

        let peers = discoveredPeers.values.sorted {
            $0.publicPeer.discoveredAt > $1.publicPeer.discoveredAt
        }

        for peer in peers {
            let connection = NWConnection(to: peer.endpoint, using: await pairingChannel.localNetworkParameters())
            do {
                try await startConnection(connection)
                let hello = try await pairingChannel.makeHandshakeHello(
                    localInvitation: hostedIdentity.invitation,
                    peerName: hostedIdentity.peerName
                )
                try await send(hello, as: .hello, over: connection)
                let ack: LocalPairingHelloAck = try await receive(LocalPairingHelloAck.self, expecting: .helloAck, over: connection)
                let session = try await pairingChannel.establishLocalSession(from: ack, for: hello)
                let peerKindMatches = preferredPeerKind == nil || session.remotePeerKind == preferredPeerKind
                let remoteRoleMatches = preferredRemoteRole == nil || session.remoteRole == preferredRemoteRole
                guard peerKindMatches, remoteRoleMatches else {
                    await pairingChannel.forgetLocalSession(id: session.id)
                    connection.cancel()
                    continue
                }
                let seal = try await pairingChannel.makeSessionSeal(for: session)
                try await send(seal, as: .sessionSeal, over: connection)
                activeSessions[session.id] = session
                sessionConnections[session.id] = connection
                startReceiveLoop(for: session.id, connection: connection)
                startNearbyVerificationIfPossible(for: session.id)
                notifyObservers()
                return session
            } catch {
                connection.cancel()
            }
        }

        throw WalletError.localPeerUnavailable
    }

    func sealSession(_ id: UUID) async {
        activeSessions[id] = nil
        receiveTasks[id]?.cancel()
        receiveTasks[id] = nil
        nearbyVerificationTasks[id]?.cancel()
        nearbyVerificationTasks[id] = nil
        pendingNearbyTokens[id] = nil
        if let connection = sessionConnections.removeValue(forKey: id) {
            connection.cancel()
        }
        await pairingChannel.forgetLocalSession(id: id)
        notifyObservers()
    }

    func sendRecoveryTransfer(_ document: RecoveryTransferDocument) async throws -> LocalRecoveryTransferReceipt {
        guard let hostedIdentity else {
            throw WalletError.localPeerTransportUnavailable
        }
        let session = try await establishSession(
            preferredPeerKind: document.envelope.recipientRole.peerKind,
            preferredRemoteRole: document.envelope.recipientRole
        )
        guard let connection = sessionConnections[session.id] else {
            throw WalletError.localPeerTransportUnavailable
        }

        let documentData = try RecoveryTransferDocument.encode(document)
        let packet = try await makeRecoveryTransferPacket(
            from: documentData,
            document: document,
            sessionID: session.id,
            senderRole: hostedIdentity.localRole,
            senderDeviceID: hostedIdentity.localDeviceID
        )
        try await send(packet, as: .recoveryTransfer, over: connection)
        return LocalRecoveryTransferReceipt(
            sessionID: session.id,
            remotePeerName: session.remotePeerName,
            remoteRole: session.remoteRole,
            documentID: document.id,
            sentAt: packet.sentAt
        )
    }

    private func handleIncomingConnection(_ connection: NWConnection) async {
        guard let hostedIdentity else {
            connection.cancel()
            return
        }

        do {
            try await startConnection(connection)
            let hello: LocalPairingHello = try await receive(LocalPairingHello.self, expecting: .hello, over: connection)
            let ack = try await pairingChannel.respond(
                to: hello,
                localInvitation: hostedIdentity.invitation,
                peerName: hostedIdentity.peerName
            )
            try await send(ack, as: .helloAck, over: connection)
            let seal: LocalPairingSessionSeal = try await receive(LocalPairingSessionSeal.self, expecting: .sessionSeal, over: connection)
            guard try await pairingChannel.verify(seal, for: hello, ack: ack) else {
                throw WalletError.invalidLocalPeerSession
            }

            let sessionSecretDigest = try await pairingChannel.sessionSecretDigest(for: ack.sessionID)
            let session = AuthenticatedLocalPeerSession(
                id: ack.sessionID,
                localInvitationID: hostedIdentity.invitation.id,
                remoteInvitationID: hello.invitation.id,
                localDeviceID: hostedIdentity.localDeviceID,
                remoteDeviceID: hello.invitation.deviceID,
                localRole: hostedIdentity.localRole,
                remoteRole: hello.invitation.deviceRole,
                remotePeerName: hello.peerName,
                remoteVerifyingKey: hello.invitation.verifyingKey,
                transport: hostedIdentity.invitation.transport,
                supportsNearbyInteraction: hello.invitation.supportsNearbyInteraction,
                remoteCapabilities: hello.invitation.capabilities,
                transcriptFingerprint: ack.sessionBindingDigest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description,
                sessionBindingDigest: ack.sessionBindingDigest,
                sessionSecretDigest: sessionSecretDigest,
                localAppAttested: ack.appAttestation != nil,
                remoteAppAttested: hello.appAttestation != nil,
                establishedAt: ack.establishedAt,
                expiresAt: ack.expiresAt,
                proximityEvidence: .authenticatedLocalChannel,
                trustLevel: .attestedLocal,
                nearbyVerification: nil
            )
            activeSessions[session.id] = session
            sessionConnections[session.id] = connection
            startReceiveLoop(for: session.id, connection: connection)
            startNearbyVerificationIfPossible(for: session.id)
            notifyObservers()
        } catch {
            connection.cancel()
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        guard let hostedIdentity else {
            discoveredPeers.removeAll()
            return
        }

        var nextPeers: [String: ResolvedPeerEndpoint] = [:]
        for result in results {
            let endpoint = result.endpoint
            let endpointLabel = endpoint.debugDescription
            let serviceName = serviceName(for: endpoint) ?? endpointLabel
            guard serviceName != hostedIdentity.serviceName else {
                continue
            }
            let id = "\(serviceName)|\(endpointLabel)"
            let publicPeer = DiscoveredLocalPeerEndpoint(
                id: id,
                serviceName: serviceName,
                advertisedRole: advertisedRole(for: serviceName),
                endpointLabel: endpointLabel,
                discoveredAt: Date()
            )
            nextPeers[id] = ResolvedPeerEndpoint(publicPeer: publicPeer, endpoint: endpoint)
        }
        discoveredPeers = nextPeers
        notifyObservers()
    }

    private func snapshot() -> LocalPeerTransportSnapshot {
        let endpointLabel: String
        if let port = listener?.port {
            endpointLabel = "Bonjour \(Self.serviceType) on port \(port.rawValue)"
        } else {
            endpointLabel = "Local pairing idle"
        }
        let availableRemoteRoles = (
            discoveredPeers.values.compactMap(\.publicPeer.advertisedRole) +
            activeSessions.values.filter(\.isActive).map(\.remoteRole)
        )
        .reduce(into: [String: DeviceRole]()) { roles, role in
            roles[role.rawValue] = role
        }
        .values
        .sorted { $0.rawValue < $1.rawValue }
        return LocalPeerTransportSnapshot(
            invitation: hostedIdentity?.invitation,
            isAdvertising: listener != nil,
            endpointLabel: endpointLabel,
            discoveredPeers: discoveredPeers.values.map(\.publicPeer).sorted { $0.discoveredAt > $1.discoveredAt },
            availableRemoteRoles: availableRemoteRoles,
            activeSessionCount: activeSessions.values.filter(\.isActive).count,
            pendingIncomingTransferCount: pendingIncomingTransfers.count
        )
    }

    private func startReceiveLoop(for sessionID: UUID, connection: NWConnection) {
        receiveTasks[sessionID]?.cancel()
        receiveTasks[sessionID] = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop(sessionID: sessionID, connection: connection)
        }
    }

    private func receiveLoop(sessionID: UUID, connection: NWConnection) async {
        while !Task.isCancelled {
            do {
                let envelope = try await receiveEnvelope(over: connection)
                switch envelope.kind {
                case .nearbyToken:
                    let packet = try decoder.decode(LocalNearbyInteractionTokenPacket.self, from: envelope.payload)
                    try await handleNearbyTokenPacket(packet, sessionID: sessionID)
                case .recoveryTransfer:
                    let packet = try decoder.decode(LocalRecoveryTransferPacket.self, from: envelope.payload)
                    try await handleRecoveryTransferPacket(packet, sessionID: sessionID)
                case .hello, .helloAck, .sessionSeal:
                    throw WalletError.invalidLocalPeerSession
                }
            } catch {
                break
            }
        }

        guard !Task.isCancelled else { return }
        await sealSession(sessionID)
    }

    private func handleRecoveryTransferPacket(
        _ packet: LocalRecoveryTransferPacket,
        sessionID: UUID
    ) async throws {
        guard packet.sessionID == sessionID,
              let hostedIdentity,
              packet.recipientRole == hostedIdentity.localRole,
              let session = activeSessions[sessionID],
              session.remoteRole == packet.senderRole,
              session.remoteDeviceID == packet.senderDeviceID else {
            throw WalletError.invalidRecoveryTransfer
        }

        let authenticatedData = recoveryTransferAuthenticatedData(for: packet)
        let documentData = try await pairingChannel.openSessionPayload(
            packet.sealedPayload,
            for: sessionID,
            authenticating: authenticatedData
        )
        let documentDigest = Data(SHA256.hash(data: documentData))
        guard documentDigest == packet.documentDigest else {
            throw WalletError.invalidRecoveryTransferDocument
        }

        let document = try RecoveryTransferDocument.decode(from: documentData)
        guard document.id == packet.documentID,
              document.envelope.senderDeviceID == packet.senderDeviceID,
              document.envelope.senderRole == packet.senderRole,
              document.envelope.recipientRole == packet.recipientRole,
              document.envelope.senderVerifyingKey == session.remoteVerifyingKey else {
            throw WalletError.invalidRecoveryTransfer
        }
        if document.envelope.senderRole.isRecoveryPeer || document.envelope.recipientRole.isRecoveryPeer {
            guard document.envelope.trustSessionFingerprint == session.transcriptFingerprint else {
                throw WalletError.invalidRecoveryTransfer
            }
        }
        guard !pendingIncomingTransfers.contains(where: {
            $0.id == packet.id || $0.document.id == document.id
        }) else {
            return
        }

        pendingIncomingTransfers.append(
            PendingLocalRecoveryTransfer(
                id: packet.id,
                sessionID: sessionID,
                peerName: session.remotePeerName,
                senderRole: packet.senderRole,
                senderDeviceID: packet.senderDeviceID,
                recipientRole: packet.recipientRole,
                document: document,
                receivedAt: Date()
            )
        )
        notifyObservers()
    }

    private func makeRecoveryTransferPacket(
        from documentData: Data,
        document: RecoveryTransferDocument,
        sessionID: UUID,
        senderRole: DeviceRole,
        senderDeviceID: String
    ) async throws -> LocalRecoveryTransferPacket {
        let sentAt = Date()
        let documentDigest = Data(SHA256.hash(data: documentData))
        let packet = LocalRecoveryTransferPacket(
            id: UUID(),
            sessionID: sessionID,
            senderRole: senderRole,
            senderDeviceID: senderDeviceID,
            recipientRole: document.envelope.recipientRole,
            documentID: document.id,
            documentDigest: documentDigest,
            sentAt: sentAt,
            sealedPayload: Data()
        )
        let authenticatedData = recoveryTransferAuthenticatedData(for: packet)
        let sealedPayload = try await pairingChannel.sealSessionPayload(
            documentData,
            for: sessionID,
            authenticating: authenticatedData
        )
        return LocalRecoveryTransferPacket(
            id: packet.id,
            sessionID: packet.sessionID,
            senderRole: packet.senderRole,
            senderDeviceID: packet.senderDeviceID,
            recipientRole: packet.recipientRole,
            documentID: packet.documentID,
            documentDigest: packet.documentDigest,
            sentAt: packet.sentAt,
            sealedPayload: sealedPayload
        )
    }

    private func recoveryTransferAuthenticatedData(for packet: LocalRecoveryTransferPacket) -> Data {
        let material = [
            packet.id.uuidString.lowercased(),
            packet.sessionID.uuidString.lowercased(),
            packet.senderRole.rawValue,
            packet.senderDeviceID,
            packet.recipientRole.rawValue,
            packet.documentID.uuidString.lowercased(),
            packet.documentDigest.base64EncodedString(),
            ISO8601DateFormatter().string(from: packet.sentAt)
        ].joined(separator: "|")
        return Data(material.utf8)
    }

    private func startNearbyVerificationIfPossible(for sessionID: UUID) {
        guard nearbyVerificationTasks[sessionID] == nil else { return }
        guard let hostedIdentity,
              hostedIdentity.invitation.supportsNearbyInteraction,
              let session = activeSessions[sessionID],
              session.isActive,
              session.supportsNearbyInteraction,
              session.remoteRole != .recoveryMac,
              session.proximityEvidence != .nearbyInteraction else {
            return
        }

        nearbyVerificationTasks[sessionID] = Task { [weak self] in
            guard let self else { return }
            await self.runNearbyVerification(for: sessionID)
        }
    }

    private func runNearbyVerification(for sessionID: UUID) async {
        defer {
            nearbyVerificationTasks[sessionID] = nil
        }

        guard let session = activeSessions[sessionID],
              session.isActive,
              let connection = sessionConnections[sessionID] else {
            return
        }

        #if canImport(NearbyInteraction) && !os(macOS)
        let verifier = await NearbyInteractionVerifier()
        defer {
            Task { @MainActor in
                verifier.invalidate()
            }
        }

        do {
            let localTokenData = try await verifier.localDiscoveryTokenData()
            let packet = try await makeNearbyTokenPacket(
                sessionID: sessionID,
                senderRole: session.localRole,
                senderDeviceID: session.localDeviceID,
                tokenData: localTokenData
            )
            try await send(packet, as: .nearbyToken, over: connection)

            let remoteTokenData = try await waitForNearbyToken(sessionID)
            let verification = try await verifier.verify(remoteTokenData: remoteTokenData)
            guard let currentSession = activeSessions[sessionID], currentSession.isActive else {
                return
            }
            activeSessions[sessionID] = currentSession.upgradingNearbyVerification(verification)
            notifyObservers()
        } catch {
            pendingNearbyTokens[sessionID] = nil
        }
        #endif
    }

    private func handleNearbyTokenPacket(
        _ packet: LocalNearbyInteractionTokenPacket,
        sessionID: UUID
    ) async throws {
        guard packet.sessionID == sessionID,
              let session = activeSessions[sessionID],
              session.remoteRole == packet.senderRole,
              session.remoteDeviceID == packet.senderDeviceID else {
            throw WalletError.invalidLocalPeerSession
        }

        let authenticatedData = nearbyTokenAuthenticatedData(for: packet)
        let tokenData = try await pairingChannel.openSessionPayload(
            packet.sealedTokenData,
            for: sessionID,
            authenticating: authenticatedData
        )
        pendingNearbyTokens[sessionID] = tokenData
    }

    private func makeNearbyTokenPacket(
        sessionID: UUID,
        senderRole: DeviceRole,
        senderDeviceID: String,
        tokenData: Data
    ) async throws -> LocalNearbyInteractionTokenPacket {
        let sentAt = Date()
        let packet = LocalNearbyInteractionTokenPacket(
            id: UUID(),
            sessionID: sessionID,
            senderRole: senderRole,
            senderDeviceID: senderDeviceID,
            sentAt: sentAt,
            sealedTokenData: Data()
        )
        let authenticatedData = nearbyTokenAuthenticatedData(for: packet)
        let sealedTokenData = try await pairingChannel.sealSessionPayload(
            tokenData,
            for: sessionID,
            authenticating: authenticatedData
        )
        return LocalNearbyInteractionTokenPacket(
            id: packet.id,
            sessionID: packet.sessionID,
            senderRole: packet.senderRole,
            senderDeviceID: packet.senderDeviceID,
            sentAt: packet.sentAt,
            sealedTokenData: sealedTokenData
        )
    }

    private func nearbyTokenAuthenticatedData(for packet: LocalNearbyInteractionTokenPacket) -> Data {
        let material = [
            packet.id.uuidString.lowercased(),
            packet.sessionID.uuidString.lowercased(),
            packet.senderRole.rawValue,
            packet.senderDeviceID,
            ISO8601DateFormatter().string(from: packet.sentAt)
        ].joined(separator: "|")
        return Data(material.utf8)
    }

    private func waitForNearbyToken(_ sessionID: UUID, timeout: TimeInterval = 10) async throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let session = activeSessions[sessionID], session.isActive else {
                throw WalletError.invalidLocalPeerSession
            }
            if let tokenData = pendingNearbyTokens.removeValue(forKey: sessionID) {
                return tokenData
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw WalletError.localPeerTransportUnavailable
    }

    private func trustRank(for trustLevel: PeerTrustLevel) -> Int {
        switch trustLevel {
        case .attestedLocal:
            return 0
        case .nearbyVerified:
            return 1
        }
    }

    private func notifyObservers() {
        let currentSnapshot = snapshot()
        for continuation in observers.values {
            continuation.yield(currentSnapshot)
        }
    }

    private func addObserver(
        _ observerID: UUID,
        continuation: AsyncStream<LocalPeerTransportSnapshot>.Continuation
    ) {
        observers[observerID] = continuation
        continuation.yield(snapshot())
    }

    private func removeObserver(_ observerID: UUID) {
        observers.removeValue(forKey: observerID)
    }

    private func startListener(_ listener: NWListener) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumeGate = ResumeGate()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeGate.resume {
                        continuation.resume(returning: ())
                    }
                case .failed(let error):
                    resumeGate.resume {
                        continuation.resume(throwing: error)
                    }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    private func startConnection(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumeGate = ResumeGate()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeGate.resume {
                        continuation.resume(returning: ())
                    }
                case .failed(let error):
                    resumeGate.resume {
                        continuation.resume(throwing: error)
                    }
                case .cancelled:
                    resumeGate.resume {
                        continuation.resume(throwing: WalletError.invalidLocalPeerSession)
                    }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send<T: Encodable>(_ value: T, as kind: WireKind, over connection: NWConnection) async throws {
        let payload = try encoder.encode(value)
        let envelope = WireEnvelope(kind: kind, payload: payload)
        let encoded = try encoder.encode(envelope)
        try await sendEncodedFrame(encoded, over: connection)
    }

    private func sendEncodedFrame(_ encoded: Data, over connection: NWConnection) async throws {
        var message = Data()
        var encodedLength = UInt32(encoded.count).bigEndian
        withUnsafeBytes(of: &encodedLength) { header in
            message.append(contentsOf: header)
        }
        message.append(encoded)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: message, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func receive<T: Decodable>(_ type: T.Type, expecting kind: WireKind, over connection: NWConnection) async throws -> T {
        let envelope = try await receiveEnvelope(over: connection)
        guard envelope.kind == kind else {
            throw WalletError.invalidLocalPeerSession
        }
        return try decoder.decode(type, from: envelope.payload)
    }

    private func receiveEnvelope(over connection: NWConnection) async throws -> WireEnvelope {
        let header = try await receiveExactLength(4, over: connection)
        let frameLength = header.withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt32.self).bigEndian
        }
        let payload = try await receiveExactLength(Int(frameLength), over: connection)
        return try decoder.decode(WireEnvelope.self, from: payload)
    }

    private func receiveExactLength(_ length: Int, over connection: NWConnection) async throws -> Data {
        var accumulated = Data()
        while accumulated.count < length {
            let chunk = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: length - accumulated.count
                ) { content, _, isComplete, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let content, !content.isEmpty {
                        continuation.resume(returning: content)
                        return
                    }
                    if isComplete {
                        continuation.resume(throwing: WalletError.invalidLocalPeerSession)
                        return
                    }
                    continuation.resume(returning: Data())
                }
            }
            accumulated.append(chunk)
        }
        return accumulated
    }

    private func serviceName(for endpoint: NWEndpoint) -> String? {
        guard case .service(let name, _, _, _) = endpoint else {
            return nil
        }
        return name
    }

    private func advertisedRole(for serviceName: String) -> DeviceRole? {
        guard serviceName.hasPrefix("numi-") else {
            return nil
        }
        let prefixDropped = serviceName.dropFirst("numi-".count)
        guard let rawRole = prefixDropped.split(separator: "-", maxSplits: 1).first else {
            return nil
        }
        return DeviceRole(rawValue: String(rawRole))
    }
}
