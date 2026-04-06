import Foundation

actor TrustLedgerStore {
    private let backupManager: BackupExclusionManager
    private let integrityProvider: StateIntegrityProvider
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        backupManager: BackupExclusionManager = BackupExclusionManager(),
        integrityProvider: StateIntegrityProvider = StateIntegrityProvider()
    ) {
        self.backupManager = backupManager
        self.integrityProvider = integrityProvider
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load(deviceID: String, role: DeviceRole) throws -> TrustLedgerSnapshot {
        let url = try backupManager.trustLedgerFileURL(deviceID: deviceID, role: role)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }

        let rawData = try Data(contentsOf: url)
        do {
            let data = try decodeStoredLedgerData(rawData)
            return try decoder.decode(TrustLedgerSnapshot.self, from: data)
        } catch {
            throw WalletError.corruptedState
        }
    }

    func recordSessionEstablished(
        _ session: PeerTrustSession,
        deviceID: String,
        localRole: DeviceRole
    ) throws -> TrustLedgerSnapshot {
        var snapshot = try load(deviceID: deviceID, role: localRole)
        let peer = TrustedPeerRecord(
            id: session.peerDeviceID,
            peerName: session.peerName,
            peerKind: session.peerKind,
            peerRole: session.peerRole,
            peerDeviceID: session.peerDeviceID,
            lastTranscriptFingerprint: session.transcriptFingerprint,
            lastTrustLevel: session.trustLevel,
            lastTransport: session.transport,
            capabilities: session.capabilities,
            lastVerifiedProximity: session.proximityEvidence,
            nearbyVerification: session.nearbyVerification,
            appAttested: session.appAttested,
            lastEstablishedAt: session.establishedAt,
            lastExpiresAt: session.expiresAt,
            lastSealedAt: nil,
            revokedAt: nil
        )
        snapshot.upsert(peer: peer)
        snapshot.prepend(
            event: TrustLedgerEvent(
                kind: .peerSessionEstablished,
                localRole: localRole,
                peerName: session.peerName,
                peerRole: session.peerRole,
                fingerprint: session.transcriptFingerprint,
                summary: "\(session.peerName) trusted for \(session.peerRole.displayName)",
                detail: "Short-lived \(session.stateLabel.lowercased()) session established over \(session.transportLabel) with \(session.proximityEvidence.label.lowercased()). Capabilities: \(session.capabilities.map(\.label).joined(separator: ", "))."
            )
        )
        try save(snapshot, deviceID: deviceID, role: localRole)
        return snapshot
    }

    func recordSessionEnded(
        _ session: PeerTrustSession,
        deviceID: String,
        localRole: DeviceRole,
        didExpire: Bool,
        reason: String
    ) throws -> TrustLedgerSnapshot {
        var snapshot = try load(deviceID: deviceID, role: localRole)
        let sealedAt = Date()
        snapshot.updatePeer(deviceID: session.peerDeviceID) { record in
            record.lastSealedAt = sealedAt
            record.lastExpiresAt = didExpire ? sealedAt : record.lastExpiresAt
        }
        snapshot.prepend(
            event: TrustLedgerEvent(
                kind: didExpire ? .peerSessionExpired : .peerSessionSealed,
                localRole: localRole,
                peerName: session.peerName,
                peerRole: session.peerRole,
                fingerprint: session.transcriptFingerprint,
                summary: didExpire ? "\(session.peerName) trust expired" : "\(session.peerName) trust sealed",
                detail: reason,
                occurredAt: sealedAt
            )
        )
        try save(snapshot, deviceID: deviceID, role: localRole)
        return snapshot
    }

    func recordTransferEnvelope(
        _ envelope: RecoveryTransferEnvelope,
        action: TrustLedgerTransferAction,
        deviceID: String,
        localRole: DeviceRole
    ) throws -> TrustLedgerSnapshot {
        var snapshot = try load(deviceID: deviceID, role: localRole)
        let kind: TrustLedgerEventKind = action == .prepared ? .recoveryEnvelopePrepared : .recoveryEnvelopeConsumed
        let detail = transferDetail(for: envelope, action: action)
        snapshot.prepend(
            event: TrustLedgerEvent(
                kind: kind,
                localRole: localRole,
                peerName: transferPeerName(for: envelope),
                peerRole: envelope.recipientRole,
                fingerprint: envelope.trustSessionFingerprint,
                summary: transferSummary(for: envelope, action: action),
                detail: detail
            )
        )
        try save(snapshot, deviceID: deviceID, role: localRole)
        return snapshot
    }

    func revokePeer(
        deviceID peerDeviceID: String,
        reason: String,
        deviceID: String,
        localRole: DeviceRole
    ) throws -> TrustLedgerSnapshot {
        var snapshot = try load(deviceID: deviceID, role: localRole)
        guard let peer = snapshot.peers.first(where: { $0.peerDeviceID == peerDeviceID }) else {
            return snapshot
        }

        let revokedAt = Date()
        snapshot.updatePeer(deviceID: peerDeviceID) { record in
            record.revokedAt = revokedAt
            record.lastSealedAt = revokedAt
            record.lastExpiresAt = min(record.lastExpiresAt, revokedAt)
        }
        snapshot.prepend(
            event: TrustLedgerEvent(
                kind: .peerRevoked,
                localRole: localRole,
                peerName: peer.peerName,
                peerRole: peer.peerRole,
                fingerprint: peer.lastTranscriptFingerprint,
                summary: "\(peer.peerName) revoked",
                detail: reason,
                occurredAt: revokedAt
            )
        )
        try save(snapshot, deviceID: deviceID, role: localRole)
        return snapshot
    }

    private func save(_ snapshot: TrustLedgerSnapshot, deviceID: String, role: DeviceRole) throws {
        var url = try backupManager.trustLedgerFileURL(deviceID: deviceID, role: role)
        let encoded = try encoder.encode(snapshot)
        let sealed = try integrityProvider.seal(encoded)
        try sealed.write(to: url, options: [.atomic])

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    private func decodeStoredLedgerData(_ rawData: Data) throws -> Data {
        if integrityProvider.isSealedEnvelope(rawData) {
            return try integrityProvider.open(rawData)
        }
        return rawData
    }

    private func transferSummary(for envelope: RecoveryTransferEnvelope, action: TrustLedgerTransferAction) -> String {
        let verb = action == .prepared ? "Prepared" : "Consumed"
        switch envelope.payload {
        case .peerShare(let share):
            return "\(verb) peer-share transfer for \(share.peerName)"
        case .authorityBundle(let shares):
            return "\(verb) authority bundle with \(shares.count) fragment(s)"
        }
    }

    private func transferDetail(for envelope: RecoveryTransferEnvelope, action: TrustLedgerTransferAction) -> String {
        let recipient = envelope.recipientRole.displayName
        let direction = action == .prepared ? "sealed for" : "accepted by"
        switch envelope.payload {
        case .peerShare(let share):
            return "Peer-share envelope \(direction) \(recipient) for \(share.peerName). Session fingerprint: \(envelope.trustSessionFingerprint ?? "none")."
        case .authorityBundle(let shares):
            let peers = shares.map(\.peerName).joined(separator: ", ")
            return "Authority-bundle envelope \(direction) \(recipient) using fragments from \(peers). Session fingerprint: \(envelope.trustSessionFingerprint ?? "none")."
        }
    }

    private func transferPeerName(for envelope: RecoveryTransferEnvelope) -> String? {
        switch envelope.payload {
        case .peerShare(let share):
            return share.peerName
        case .authorityBundle(let shares):
            return shares.map(\.peerName).joined(separator: ", ")
        }
    }
}
