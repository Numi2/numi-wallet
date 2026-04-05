import Foundation

struct OutgoingTagPlan {
    var tag: Data
    var relationshipID: UUID?
    var introductionEncapsulatedKey: Data?
    var isIntroductionPayment: Bool
}

actor ShieldedStateCoordinator {
    private let configuration: RemoteServiceConfiguration
    private let pirClient: PIRClient
    private let descriptorSecretStore: DescriptorSecretStore
    private let ratchetSecretStore: RatchetSecretStore
    private let tagRatchetEngine: TagRatchetEngine
    private let codec: EnvelopeCodec

    init(
        configuration: RemoteServiceConfiguration,
        pirClient: PIRClient,
        descriptorSecretStore: DescriptorSecretStore,
        ratchetSecretStore: RatchetSecretStore,
        tagRatchetEngine: TagRatchetEngine,
        codec: EnvelopeCodec
    ) {
        self.configuration = configuration
        self.pirClient = pirClient
        self.descriptorSecretStore = descriptorSecretStore
        self.ratchetSecretStore = ratchetSecretStore
        self.tagRatchetEngine = tagRatchetEngine
        self.codec = codec
    }

    func prepareOutgoingTag(
        profile: inout WalletProfile,
        alias: String?,
        descriptor: PrivateReceiveDescriptor
    ) async throws -> OutgoingTagPlan {
        guard configuration.supportsTagRatchets else {
            return OutgoingTagPlan(
                tag: Data(),
                relationshipID: nil,
                introductionEncapsulatedKey: nil,
                isIntroductionPayment: false
            )
        }

        if let index = profile.shielded.relationships.firstIndex(where: { $0.peerDescriptorID == descriptor.id }) {
            var relationship = profile.shielded.relationships[index]
            var secrets = try await ratchetSecretStore.load(relationshipID: relationship.id)
            let ratcheted = tagRatchetEngine.advanceOutgoingTag(using: secrets)
            secrets.outgoingChainKey = ratcheted.updatedChainKey
            relationship.nextOutgoingCounter += 1
            relationship.lastActivityAt = Date()
            if relationship.direction == .inbound {
                relationship.direction = .bidirectional
            }
            profile.shielded.relationships[index] = relationship
            try await ratchetSecretStore.store(secrets, relationshipID: relationship.id)
            return OutgoingTagPlan(
                tag: ratcheted.tag,
                relationshipID: relationship.id,
                introductionEncapsulatedKey: nil,
                isIntroductionPayment: false
            )
        }

        let established = try tagRatchetEngine.establishRelationship(alias: alias, peerDescriptor: descriptor)
        let ratcheted = tagRatchetEngine.advanceOutgoingTag(using: established.secrets)
        var storedSecrets = established.secrets
        storedSecrets.outgoingChainKey = ratcheted.updatedChainKey

        var relationship = established.snapshot
        relationship.nextOutgoingCounter = 1
        relationship.lastActivityAt = Date()
        profile.shielded.relationships.append(relationship)
        try await ratchetSecretStore.store(storedSecrets, relationshipID: relationship.id)

        return OutgoingTagPlan(
            tag: ratcheted.tag,
            relationshipID: relationship.id,
            introductionEncapsulatedKey: established.introductionEncapsulatedKey,
            isIntroductionPayment: true
        )
    }

    func refresh(
        profile: inout WalletProfile,
        activeDescriptors: [PrivateReceiveDescriptor],
        trigger: ShieldedRefreshTrigger
    ) async throws -> ShieldedRefreshReport {
        guard configuration.supportsPIRStateUpdates else {
            profile.shielded.pirSync.lastBandwidth = .zero
            profile.shielded.pirSync.readyForImmediateSpend = false
            profile.shielded.pirSync.lastError = nil
            return ShieldedRefreshReport(
                noteCount: profile.shielded.notes.count,
                spendableNoteCount: 0,
                lastKnownBlockHeight: profile.shielded.pirSync.lastKnownBlockHeight,
                bandwidth: .zero,
                readyForImmediateSpend: false
            )
        }

        let descriptorsByID = Dictionary(uniqueKeysWithValues: activeDescriptors.map { ($0.id, $0) })
        var bandwidth = PIRBandwidthSnapshot.zero

        let tagPlan = configuration.supportsTagRatchets
            ? try await buildTagQueryPlan(profile: profile, activeDescriptors: activeDescriptors)
            : TagQueryPlan()
        let tagResponse: PIRTagLookupResponse
        if tagPlan.allTags.isEmpty {
            tagResponse = PIRTagLookupResponse(
                blockHeight: profile.shielded.pirSync.lastKnownBlockHeight,
                matches: []
            )
        } else {
            tagResponse = try await pirClient.fetchTagMatches(tagPlan.allTags)
            bandwidth.tagBytes = approximateEnvelopeBytes(for: tagPlan.allTags)
            profile.shielded.pirSync.lastKnownBlockHeight = tagResponse.blockHeight
        }

        for match in tagResponse.matches {
            guard let descriptor = descriptorsByID[match.recipientDescriptorID] else {
                continue
            }
            let payload = try await decodeRecipientPayload(match: match, descriptor: descriptor)
            guard !profile.shielded.notes.contains(where: { $0.noteCommitment == payload.noteCommitment }) else {
                continue
            }
            let relationshipID = try await consumeIncomingMatch(
                profile: &profile,
                descriptor: descriptor,
                match: match,
                queryPlan: tagPlan
            )
            profile.shielded.notes.append(
                ShieldedNoteWitness(
                    id: UUID(),
                    tier: descriptor.tier,
                    noteCommitment: payload.noteCommitment,
                    nullifier: payload.nullifier,
                    amount: payload.amount,
                    memo: payload.memo,
                    receivedAt: payload.createdAt,
                    descriptorID: descriptor.id,
                    relationshipID: relationshipID,
                    latestTag: match.tag,
                    merklePath: nil,
                    lastMerkleUpdateAt: nil,
                    lastNullifierCheckAt: nil,
                    spendState: .ready
                )
            )
        }

        let liveNotes = profile.shielded.notes.filter { $0.spendState != .spent }
        if !liveNotes.isEmpty {
            let nullifierResponse = try await pirClient.fetchNullifierStatuses(liveNotes.map(\.nullifier))
            let spentSet = Set(nullifierResponse.spentNullifiers)
            bandwidth.nullifierBytes = approximateEnvelopeBytes(for: liveNotes.map(\.nullifier))
            profile.shielded.pirSync.lastKnownBlockHeight = max(profile.shielded.pirSync.lastKnownBlockHeight, nullifierResponse.blockHeight)

            for index in profile.shielded.notes.indices {
                if spentSet.contains(profile.shielded.notes[index].nullifier) {
                    profile.shielded.notes[index].spendState = .spent
                }
                profile.shielded.notes[index].lastNullifierCheckAt = Date()
            }

            let unspentNotes = profile.shielded.notes.filter { $0.spendState != .spent }
            let merkleResponse = try await pirClient.fetchMerklePaths(for: unspentNotes.map(\.noteCommitment))
            let pathsByCommitment = Dictionary(uniqueKeysWithValues: merkleResponse.paths.map { ($0.noteCommitment, $0.path) })
            bandwidth.merklePathBytes = approximateEnvelopeBytes(for: unspentNotes.map(\.noteCommitment))
            profile.shielded.pirSync.lastKnownBlockHeight = max(profile.shielded.pirSync.lastKnownBlockHeight, merkleResponse.blockHeight)

            for index in profile.shielded.notes.indices {
                if let path = pathsByCommitment[profile.shielded.notes[index].noteCommitment] {
                    profile.shielded.notes[index].merklePath = path
                    profile.shielded.notes[index].lastMerkleUpdateAt = Date()
                }
            }
        }

        let readyCount = profile.shielded.notes.filter(\.isSpendable).count
        profile.shielded.pirSync.lastRefreshAt = Date()
        profile.shielded.pirSync.lastBandwidth = bandwidth
        profile.shielded.pirSync.readyForImmediateSpend = readyCount > 0
        profile.shielded.pirSync.lastError = nil

        return ShieldedRefreshReport(
            noteCount: profile.shielded.notes.count,
            spendableNoteCount: readyCount,
            lastKnownBlockHeight: profile.shielded.pirSync.lastKnownBlockHeight,
            bandwidth: bandwidth,
            readyForImmediateSpend: readyCount > 0
        )
    }

    private func buildTagQueryPlan(
        profile: WalletProfile,
        activeDescriptors: [PrivateReceiveDescriptor]
    ) async throws -> TagQueryPlan {
        var plan = TagQueryPlan()

        for descriptor in activeDescriptors where !descriptor.taggingPublicKey.isEmpty {
            let tag = tagRatchetEngine.bootstrapTag(for: descriptor)
            plan.bootstrapDescriptorByTag[tag] = descriptor.id
            plan.allTags.append(tag)
        }

        for relationship in profile.shielded.relationships {
            let secrets = try await ratchetSecretStore.load(relationshipID: relationship.id)
            let lookahead = tagRatchetEngine.lookaheadTags(using: secrets.incomingChainKey, count: 4)
            for (offset, tag) in lookahead.enumerated() {
                plan.relationshipByTag[tag] = (relationship.id, offset + 1)
                plan.allTags.append(tag)
            }
        }

        return plan
    }

    private func decodeRecipientPayload(
        match: TaggedPaymentMatch,
        descriptor: PrivateReceiveDescriptor
    ) async throws -> ShieldedRecipientPayload {
        let material = try await descriptorSecretStore.load(descriptorID: descriptor.id, tier: descriptor.tier)
        let plaintext = try codec.decryptRelayPayload(
            match.noteCiphertext,
            descriptorPrivateKey: material.deliveryKey,
            descriptor: descriptor
        )
        return try JSONDecoder().decode(ShieldedRecipientPayload.self, from: plaintext)
    }

    private func consumeIncomingMatch(
        profile: inout WalletProfile,
        descriptor: PrivateReceiveDescriptor,
        match: TaggedPaymentMatch,
        queryPlan: TagQueryPlan
    ) async throws -> UUID? {
        if let relationshipInfo = queryPlan.relationshipByTag[match.tag],
           let index = profile.shielded.relationships.firstIndex(where: { $0.id == relationshipInfo.relationshipID }) {
            var relationship = profile.shielded.relationships[index]
            var secrets = try await ratchetSecretStore.load(relationshipID: relationship.id)
            for _ in 0..<relationshipInfo.steps {
                let ratcheted = tagRatchetEngine.advanceIncomingTag(using: secrets)
                secrets.incomingChainKey = ratcheted.updatedChainKey
            }
            relationship.nextIncomingCounter += UInt64(relationshipInfo.steps)
            relationship.lastActivityAt = Date()
            if relationship.direction == .outbound {
                relationship.direction = .bidirectional
            }
            profile.shielded.relationships[index] = relationship
            try await ratchetSecretStore.store(secrets, relationshipID: relationship.id)
            return relationship.id
        }

        guard let introductionKey = match.senderIntroductionEncapsulatedKey else {
            return nil
        }

        let descriptorMaterial = try await descriptorSecretStore.load(descriptorID: descriptor.id, tier: descriptor.tier)
        let derived = try tagRatchetEngine.deriveRecipientRelationship(
            alias: descriptor.aliasHint,
            descriptor: descriptor,
            descriptorSecrets: descriptorMaterial,
            introductionEncapsulatedKey: introductionKey
        )
        var relationship = derived.snapshot
        var secrets = derived.secrets
        let ratcheted = tagRatchetEngine.advanceIncomingTag(using: secrets)
        secrets.incomingChainKey = ratcheted.updatedChainKey
        relationship.nextIncomingCounter = 1
        relationship.lastActivityAt = Date()
        profile.shielded.relationships.append(relationship)
        try await ratchetSecretStore.store(secrets, relationshipID: relationship.id)
        return relationship.id
    }

    private func approximateEnvelopeBytes(for payloads: [Data]) -> Int {
        payloads.reduce(0) { partialResult, payload in
            partialResult + payload.count + 96
        }
    }
}

private struct TagQueryPlan {
    var allTags: [Data] = []
    var bootstrapDescriptorByTag: [Data: UUID] = [:]
    var relationshipByTag: [Data: (relationshipID: UUID, steps: Int)] = [:]
}
