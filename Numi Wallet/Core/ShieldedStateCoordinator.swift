import Foundation
import Security

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
    private let tachyonDiscoveryAdapter: any TachyonDiscoveryAdapter
    private let tachyonStateAdapter: any TachyonStateAdapter

    init(
        configuration: RemoteServiceConfiguration,
        pirClient: PIRClient,
        descriptorSecretStore: DescriptorSecretStore,
        ratchetSecretStore: RatchetSecretStore,
        tagRatchetEngine: TagRatchetEngine,
        codec: EnvelopeCodec,
        tachyonDiscoveryAdapter: any TachyonDiscoveryAdapter = DefaultTachyonDiscoveryAdapter(),
        tachyonStateAdapter: any TachyonStateAdapter = DefaultTachyonStateAdapter()
    ) {
        self.configuration = configuration
        self.pirClient = pirClient
        self.descriptorSecretStore = descriptorSecretStore
        self.ratchetSecretStore = ratchetSecretStore
        self.tagRatchetEngine = tagRatchetEngine
        self.codec = codec
        self.tachyonDiscoveryAdapter = tachyonDiscoveryAdapter
        self.tachyonStateAdapter = tachyonStateAdapter
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

        if let index = profile.shielded.relationships.firstIndex(where: {
            $0.peerDescriptorID == descriptor.id && $0.state != .revoked
        }) {
            var relationship = profile.shielded.relationships[index]
            var secrets = try await ratchetSecretStore.load(relationshipID: relationship.id)
            let ratcheted = tagRatchetEngine.advanceOutgoingTag(using: secrets)
            secrets.outgoingChainKey = ratcheted.updatedChainKey
            relationship.nextOutgoingCounter += 1
            relationship.lastActivityAt = Date()
            relationship.direction = reconciledDirection(for: relationship)
            relationship.state = preparedOutgoingState(for: relationship, isIntroductionPayment: false)
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
        relationship.direction = reconciledDirection(for: relationship)
        relationship.state = preparedOutgoingState(for: relationship, isIntroductionPayment: true)
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
        trigger: ShieldedRefreshTrigger,
        checkpoint: ((WalletProfile) async throws -> Void)? = nil
    ) async throws -> ShieldedRefreshReport {
        guard configuration.supportsPIRStateUpdates else {
            profile.shielded.pirSync.lastBandwidth = .zero
            profile.shielded.pirSync.readyForImmediateSpend = false
            profile.shielded.pirSync.lastError = nil
            profile.shielded.pirSync.readinessClassification = .stale
            profile.shielded.pirSync.readinessLease = nil
            profile.shielded.pirSync.disputeEvidence = nil
            profile.shielded.pirSync.recentReceipts = []
            return ShieldedRefreshReport(
                noteCount: profile.shielded.notes.count,
                discoveredNoteCount: profile.shielded.notes.filter { $0.readinessState == .discovered }.count,
                verifiedNoteCount: profile.shielded.notes.filter { $0.readinessState == .verified }.count,
                witnessFreshNoteCount: profile.shielded.notes.filter { $0.readinessState == .witnessFresh }.count,
                spendableNoteCount: 0,
                lastKnownBlockHeight: profile.shielded.pirSync.lastKnownBlockHeight,
                bandwidth: .zero,
                readyForImmediateSpend: false,
                readinessClassification: .stale,
                leaseExpiresAt: nil,
                mismatchCount: profile.shielded.pirSync.mismatchEvents.count,
                deferredMatchCount: 0
            )
        }

        let refreshStartedAt = Date()
        let priorSync = profile.shielded.pirSync
        let priorLease = priorSync.readinessLease
        let priorTrustedHeight = priorLease?.trustedBlockHeight ?? priorSync.lastKnownBlockHeight
        let descriptorsByID = Dictionary(uniqueKeysWithValues: activeDescriptors.map { ($0.id, $0) })
        let knownDescriptorIDs = Set(activeDescriptors.map(\.id))
        var bandwidth = PIRBandwidthSnapshot.zero
        var readinessClassification: PIRReadinessClassification = .ready
        var readinessDetail = "PIR readiness lease refreshed."
        var deferredMatchCount = 0
        var disputeDetected = false
        var providersByID = Dictionary(uniqueKeysWithValues: priorSync.providers.map { ($0.id, $0) })
        var receipts = priorSync.recentReceipts
        var mismatchEvents = priorSync.mismatchEvents
        profile.shielded.pirSync.queryPolicies = PIRQueryPolicy.defaultPolicies
        refreshRelationshipStates(in: &profile, referenceDate: refreshStartedAt)

        let tagPlanResolution = configuration.supportsTagRatchets
            ? try await resolveTagQueryPlan(
                profile: &profile,
                activeDescriptors: activeDescriptors,
                trigger: trigger,
                refreshTicketLedger: priorSync.refreshTicketLedger
            )
            : TagPlanResolution(plan: TagQueryPlan(), usedCachedTickets: false, cachedTicketsUnavailable: false)
        let tagPlan = tagPlanResolution.plan

        if tagPlanResolution.usedCachedTickets {
            readinessClassification = combineReadinessClassification(readinessClassification, .degraded)
            readinessDetail = "Background refresh used cached PIR tickets; any new encrypted matches stay deferred until the device is unlocked."
        } else if tagPlanResolution.cachedTicketsUnavailable {
            readinessClassification = combineReadinessClassification(readinessClassification, .degraded)
            readinessDetail = "Quick private refresh required to rebuild discovery tickets."
        }

        do {
            try await resumeInterruptedInboxEntries(
                profile: &profile,
                descriptorsByID: descriptorsByID,
                checkpoint: checkpoint
            )
        } catch {
            guard trigger == .backgroundMaintenance, isProtectedDataAccessFailure(error) else {
                throw error
            }
            deferredMatchCount += profile.shielded.inboxJournal.filter {
                $0.stage == .payloadDecrypted || $0.stage == .payloadValidated
            }.count
            readinessClassification = combineReadinessClassification(readinessClassification, .degraded)
            readinessDetail = "Background refresh deferred interrupted note ingestion until the device is unlocked."
        }

        var observedBlockHeights: [UInt64] = []
        let tagResponse: PIRTagLookupResponse
        if tagPlan.allTags.isEmpty {
            tagResponse = PIRTagLookupResponse(
                blockHeight: priorTrustedHeight,
                matches: []
            )
        } else {
            let tagResult = try await pirClient.fetchTagMatches(tagPlan.allTags)
            let tagReceipt = makeQueryReceipt(
                from: tagResult.receipt,
                blockHeight: tagResult.response.blockHeight,
                responseItemCount: tagResult.response.matches.count
            )
            receipts.append(tagReceipt)
            providersByID[tagResult.receipt.provider.id] = tagResult.receipt.provider
            observedBlockHeights.append(tagResult.response.blockHeight)
            if tagResult.response.blockHeight < priorTrustedHeight {
                readinessClassification = combineReadinessClassification(readinessClassification, .stale)
                readinessDetail = "Tag discovery returned an older chain height than the last trusted readiness lease."
                mismatchEvents.append(
                    makeMismatchEvent(
                        queryClass: .tagDiscovery,
                        providerIDs: [tagResult.receipt.provider.id],
                        reason: "Tag discovery block height regressed below the last trusted lease.",
                        expectedBlockHeight: priorTrustedHeight,
                        observedBlockHeight: tagResult.response.blockHeight
                    )
                )
            }
            bandwidth.tagBytes = approximateEnvelopeBytes(for: tagPlan.allTags)
            tagResponse = tagResult.response
        }

        for match in tagResponse.matches {
            guard let descriptor = descriptorsByID[match.recipientDescriptorID] else {
                continue
            }
            let tagDigest = TachyonSupport.digest(match.tag)
            let interpretedMatch = tachyonDiscoveryAdapter.interpret(
                match,
                tagDigest: tagDigest,
                knownDescriptorIDs: knownDescriptorIDs
            )
            let relationshipInfo = tagPlan.relationshipByTagDigest[interpretedMatch.tagDigest]
            if isReplayMatch(
                profile: profile,
                relationshipID: relationshipInfo?.relationshipID,
                tagDigest: interpretedMatch.tagDigest,
                ciphertextDigest: interpretedMatch.ciphertextDigest
            ) {
                continue
            }
            let journalID = upsertInboxJournalEntry(
                in: &profile,
                entry: ShieldedInboxJournalEntry(
                    id: UUID(),
                    stage: .matchReceived,
                    tagDigest: interpretedMatch.tagDigest,
                    ciphertextDigest: interpretedMatch.ciphertextDigest,
                    descriptorID: descriptor.id,
                    relationshipID: relationshipInfo?.relationshipID,
                    noteID: nil,
                    noteCommitment: nil,
                    receivedAt: match.receivedAt,
                    updatedAt: refreshStartedAt,
                    detail: "Matched incoming Tachyon discovery tag.",
                    resumptionMaterial: ShieldedInboxResumptionMaterial(
                        matchedTag: match.tag,
                        senderIntroductionEncapsulatedKey: match.senderIntroductionEncapsulatedKey,
                        lookaheadStep: relationshipInfo?.steps,
                        decryptedPayload: nil,
                        decodedNote: nil
                    )
                )
            )
            try await checkpoint?(profile)
            do {
                let payload = try await decodeRecipientPayload(match: match, descriptor: descriptor)
                setInboxJournalResumptionMaterial(
                    in: &profile,
                    id: journalID,
                    material: ShieldedInboxResumptionMaterial(
                        matchedTag: match.tag,
                        senderIntroductionEncapsulatedKey: match.senderIntroductionEncapsulatedKey,
                        lookaheadStep: relationshipInfo?.steps,
                        decryptedPayload: payload,
                        decodedNote: nil
                    )
                )
                updateInboxJournalEntry(
                    in: &profile,
                    id: journalID,
                    stage: .payloadDecrypted,
                    detail: "Recipient payload decrypted on device."
                )
                try await checkpoint?(profile)
                try await continueMatchIngestion(
                    profile: &profile,
                    journalID: journalID,
                    descriptor: descriptor,
                    matchedRelationshipID: relationshipInfo?.relationshipID,
                    lookaheadStep: relationshipInfo?.steps,
                    tagDigest: interpretedMatch.tagDigest,
                    ciphertextDigest: interpretedMatch.ciphertextDigest,
                    payload: payload,
                    matchTag: match.tag,
                    senderIntroductionEncapsulatedKey: match.senderIntroductionEncapsulatedKey,
                    receivedAt: match.receivedAt,
                    checkpoint: checkpoint
                )
            } catch {
                if trigger == .backgroundMaintenance, isProtectedDataAccessFailure(error) {
                    deferredMatchCount += 1
                    readinessClassification = combineReadinessClassification(readinessClassification, .degraded)
                    readinessDetail = "Background refresh deferred \(deferredMatchCount) incoming matches until protected data becomes available."
                    updateInboxJournalEntry(
                        in: &profile,
                        id: journalID,
                        stage: .deferred,
                        detail: "Incoming payload deferred until the device is unlocked."
                    )
                    try await checkpoint?(profile)
                    continue
                }
                updateInboxJournalEntry(
                    in: &profile,
                    id: journalID,
                    stage: .failed,
                    detail: "Incoming match failed: \(error.localizedDescription)"
                )
                try await checkpoint?(profile)
                throw error
            }
        }

        let liveNotes = profile.shielded.notes.filter { $0.spendState != .spent }
        var observedAnchorRoot: Data?
        if !liveNotes.isEmpty {
            let nullifierInputs = tachyonStateAdapter.nullifierQueryInputs(for: liveNotes)
            let nullifierResult = try await pirClient.fetchNullifierStatuses(nullifierInputs)
            let nullifierReceipt = makeQueryReceipt(
                from: nullifierResult.receipt,
                blockHeight: nullifierResult.response.blockHeight,
                responseItemCount: nullifierResult.response.spentNullifiers.count
            )
            receipts.append(nullifierReceipt)
            providersByID[nullifierResult.receipt.provider.id] = nullifierResult.receipt.provider
            observedBlockHeights.append(nullifierResult.response.blockHeight)
            if nullifierResult.response.blockHeight < priorTrustedHeight {
                readinessClassification = combineReadinessClassification(readinessClassification, .stale)
                readinessDetail = "Nullifier status refresh returned an older chain height than the last trusted readiness lease."
                mismatchEvents.append(
                    makeMismatchEvent(
                        queryClass: .nullifierStatuses,
                        providerIDs: [nullifierResult.receipt.provider.id],
                        reason: "Nullifier status block height regressed below the last trusted lease.",
                        expectedBlockHeight: priorTrustedHeight,
                        observedBlockHeight: nullifierResult.response.blockHeight
                    )
                )
            }
            let spentSet = Set(nullifierResult.response.spentNullifiers)
            bandwidth.nullifierBytes = approximateEnvelopeBytes(for: nullifierInputs)

            for index in profile.shielded.notes.indices {
                if spentSet.contains(profile.shielded.notes[index].nullifier) {
                    profile.shielded.notes[index].spendState = .spent
                }
                profile.shielded.notes[index].lastNullifierCheckAt = refreshStartedAt
                profile.shielded.notes[index].readinessState = classifyReadiness(for: profile.shielded.notes[index])
            }
            try await checkpoint?(profile)

            let unspentNotes = profile.shielded.notes.filter { $0.spendState != .spent }
            if !unspentNotes.isEmpty {
                let merkleResult = try await pirClient.fetchMerklePaths(for: unspentNotes.map(\.noteCommitment))
                let roots = Set(merkleResult.response.paths.map(\.path.root))
                let anchorHeights = Set(merkleResult.response.paths.map(\.path.anchorHeight))
                let anchorRoot = roots.count == 1 ? roots.first : nil
                let merkleReceipt = makeQueryReceipt(
                    from: merkleResult.receipt,
                    blockHeight: merkleResult.response.blockHeight,
                    responseItemCount: merkleResult.response.paths.count,
                    anchorRoot: anchorRoot
                )
                receipts.append(merkleReceipt)
                providersByID[merkleResult.receipt.provider.id] = merkleResult.receipt.provider
                observedBlockHeights.append(merkleResult.response.blockHeight)
                bandwidth.merklePathBytes = approximateEnvelopeBytes(for: unspentNotes.map(\.noteCommitment))
                if merkleResult.response.blockHeight < priorTrustedHeight {
                    readinessClassification = combineReadinessClassification(readinessClassification, .stale)
                    readinessDetail = "Merkle witness refresh returned an older chain height than the last trusted readiness lease."
                    mismatchEvents.append(
                        makeMismatchEvent(
                            queryClass: .merklePaths,
                            providerIDs: [merkleResult.receipt.provider.id],
                            reason: "Merkle witness block height regressed below the last trusted lease.",
                            expectedBlockHeight: priorTrustedHeight,
                            observedBlockHeight: merkleResult.response.blockHeight
                        )
                    )
                }
                if roots.count > 1 || anchorHeights.count > 1 {
                    disputeDetected = true
                    readinessClassification = combineReadinessClassification(readinessClassification, .disputed)
                    readinessDetail = "Merkle witness refresh returned inconsistent anchor state; prior readiness lease preserved."
                    mismatchEvents.append(
                        makeMismatchEvent(
                            queryClass: .merklePaths,
                            providerIDs: [merkleResult.receipt.provider.id],
                            reason: "Merkle witness response contained multiple anchor roots or heights.",
                            observedDigest: anchorRoot.map { TachyonSupport.digest($0) }
                        )
                    )
                }
                let pathsByCommitment = Dictionary(uniqueKeysWithValues: merkleResult.response.paths.map { ($0.noteCommitment, $0.path) })
                if pathsByCommitment.count != unspentNotes.count {
                    disputeDetected = true
                    readinessClassification = combineReadinessClassification(readinessClassification, .disputed)
                    readinessDetail = "Merkle witness refresh omitted one or more requested notes; prior readiness lease preserved."
                    mismatchEvents.append(
                        makeMismatchEvent(
                            queryClass: .merklePaths,
                            providerIDs: [merkleResult.receipt.provider.id],
                            reason: "Merkle witness response omitted at least one requested note commitment."
                        )
                    )
                }
                observedAnchorRoot = anchorRoot

                for index in profile.shielded.notes.indices {
                    if let path = pathsByCommitment[profile.shielded.notes[index].noteCommitment] {
                        profile.shielded.notes[index].merklePath = path
                        profile.shielded.notes[index].lastMerkleUpdateAt = refreshStartedAt
                        updateInboxJournalEntries(
                            in: &profile,
                            matching: profile.shielded.notes[index].noteCommitment,
                            stage: .witnessRefreshed,
                            noteID: profile.shielded.notes[index].id,
                            detail: "Merkle witness refreshed for discovered note."
                        )
                    }
                    profile.shielded.notes[index].readinessState = classifyReadiness(for: profile.shielded.notes[index])
                    updateInboxJournalEntries(
                        in: &profile,
                        matching: profile.shielded.notes[index].noteCommitment,
                        stage: .spendabilityClassified,
                        noteID: profile.shielded.notes[index].id,
                        detail: detailForReadinessState(profile.shielded.notes[index].readinessState)
                    )
                }
                try await checkpoint?(profile)
            }
        }

        let readyCount = profile.shielded.notes.filter(\.isSpendable).count
        let discoveredCount = profile.shielded.notes.filter { $0.readinessState == .discovered }.count
        let verifiedCount = profile.shielded.notes.filter { $0.readinessState == .verified }.count
        let witnessFreshCount = profile.shielded.notes.filter { $0.readinessState == .witnessFresh }.count
        receipts = trimReceipts(receipts)
        mismatchEvents = trimMismatchEvents(mismatchEvents)
        let refreshTicketLedger = makeRefreshTicketLedger(
            profile: profile,
            tagPlan: tagPlan,
            generatedAt: refreshStartedAt
        )
        let effectiveProviders = providersByID.values.sorted { $0.id < $1.id }
        let effectiveTrustedHeight: UInt64
        switch readinessClassification {
        case .ready:
            effectiveTrustedHeight = max(priorTrustedHeight, observedBlockHeights.max() ?? priorTrustedHeight)
        case .stale, .degraded, .disputed:
            if priorTrustedHeight > 0 || priorSync.lastKnownBlockHeight > 0 {
                effectiveTrustedHeight = max(priorTrustedHeight, priorSync.lastKnownBlockHeight)
            } else {
                effectiveTrustedHeight = observedBlockHeights.max() ?? 0
            }
        }
        let evidence: PIRDisputeEvidenceSnapshot?
        if disputeDetected || readinessClassification == .disputed {
            evidence = makeDisputeEvidence(
                receipts: receipts,
                mismatchEvents: mismatchEvents,
                notes: profile.shielded.notes,
                tagPlan: tagPlan,
                capturedAt: refreshStartedAt
            )
        } else {
            evidence = nil
        }
        let readinessLease = makeReadinessLease(
            classification: readinessClassification,
            priorLease: priorLease,
            trustedBlockHeight: effectiveTrustedHeight,
            anchorRoot: readinessClassification == .ready ? observedAnchorRoot : (priorLease?.anchorRoot ?? observedAnchorRoot),
            providerIDs: effectiveProviders.map(\.id),
            ticketLedger: refreshTicketLedger,
            evidence: evidence,
            issuedAt: refreshStartedAt,
            detail: readinessDetail
        )

        profile.shielded.pirSync.lastRefreshAt = refreshStartedAt
        profile.shielded.pirSync.lastKnownBlockHeight = effectiveTrustedHeight
        profile.shielded.pirSync.lastBandwidth = bandwidth
        profile.shielded.pirSync.readyForImmediateSpend = readyCount > 0 && readinessLease.permitsImmediateSpend
        profile.shielded.pirSync.lastError = readinessClassification == .ready ? nil : readinessDetail
        profile.shielded.pirSync.readinessClassification = readinessClassification
        profile.shielded.pirSync.providers = effectiveProviders
        profile.shielded.pirSync.recentReceipts = receipts
        profile.shielded.pirSync.mismatchEvents = mismatchEvents
        profile.shielded.pirSync.disputeEvidence = evidence
        profile.shielded.pirSync.readinessLease = readinessLease
        profile.shielded.pirSync.refreshTicketLedger = refreshTicketLedger

        return ShieldedRefreshReport(
            noteCount: profile.shielded.notes.count,
            discoveredNoteCount: discoveredCount,
            verifiedNoteCount: verifiedCount,
            witnessFreshNoteCount: witnessFreshCount,
            spendableNoteCount: readyCount,
            lastKnownBlockHeight: effectiveTrustedHeight,
            bandwidth: bandwidth,
            readyForImmediateSpend: readyCount > 0 && readinessLease.permitsImmediateSpend,
            readinessClassification: readinessClassification,
            leaseExpiresAt: readinessLease.expiresAt,
            mismatchCount: mismatchEvents.count,
            deferredMatchCount: deferredMatchCount
        )
    }

    func finalizeSubmittedOutgoingTag(
        profile: inout WalletProfile,
        relationshipID: UUID,
        isIntroductionPayment: Bool
    ) {
        guard let index = profile.shielded.relationships.firstIndex(where: { $0.id == relationshipID }) else {
            return
        }
        var relationship = profile.shielded.relationships[index]
        relationship.lastActivityAt = Date()
        relationship.state = submittedOutgoingState(for: relationship, isIntroductionPayment: isIntroductionPayment)
        profile.shielded.relationships[index] = relationship
    }

    func discardPreparedOutgoingTag(
        profile: inout WalletProfile,
        relationshipID: UUID,
        isIntroductionPayment: Bool
    ) async throws {
        guard let index = profile.shielded.relationships.firstIndex(where: { $0.id == relationshipID }) else {
            return
        }

        let relationship = profile.shielded.relationships[index]
        if isIntroductionPayment && relationship.nextIncomingCounter == 0 && relationship.nextOutgoingCounter <= 1 {
            profile.shielded.relationships.remove(at: index)
            try await ratchetSecretStore.deleteSecrets(for: [relationshipID])
            return
        }

        // Established relationships keep the ratchet advanced even when a capsule is discarded.
        profile.shielded.relationships[index].state = inferredActiveState(for: relationship)
    }

    private func buildTagQueryPlan(
        profile: inout WalletProfile,
        activeDescriptors: [PrivateReceiveDescriptor]
    ) async throws -> TagQueryPlan {
        var plan = TagQueryPlan()

        for descriptor in activeDescriptors where !descriptor.taggingPublicKey.isEmpty {
            let tag = tagRatchetEngine.bootstrapTag(for: descriptor)
            let query = tachyonDiscoveryAdapter.makeBootstrapQuery(tag: tag, descriptorID: descriptor.id)
            plan.queries.append(query)
            plan.bootstrapDescriptorByTagDigest[query.tagDigest] = descriptor.id
        }

        for index in profile.shielded.relationships.indices {
            guard profile.shielded.relationships[index].state != .revoked else {
                continue
            }
            let relationship = profile.shielded.relationships[index]
            let secrets = try await ratchetSecretStore.load(relationshipID: relationship.id)
            let lookaheadWindowSize = max(relationship.lookaheadWindowSize, 1)
            let lookahead = tagRatchetEngine.lookaheadTags(using: secrets.incomingChainKey, count: lookaheadWindowSize)
            for (offset, tag) in lookahead.enumerated() {
                let query = tachyonDiscoveryAdapter.makeRatchetedQuery(
                    tag: tag,
                    relationshipID: relationship.id,
                    lookaheadStep: offset + 1
                )
                plan.queries.append(query)
                plan.relationshipByTagDigest[query.tagDigest] = (relationship.id, offset + 1)
            }
            profile.shielded.relationships[index].lastIssuedIncomingLookaheadCounter = relationship.nextIncomingCounter + UInt64(lookaheadWindowSize)
        }

        return plan
    }

    private func resolveTagQueryPlan(
        profile: inout WalletProfile,
        activeDescriptors: [PrivateReceiveDescriptor],
        trigger: ShieldedRefreshTrigger,
        refreshTicketLedger: PIRRefreshTicketLedger?
    ) async throws -> TagPlanResolution {
        do {
            return TagPlanResolution(
                plan: try await buildTagQueryPlan(profile: &profile, activeDescriptors: activeDescriptors),
                usedCachedTickets: false,
                cachedTicketsUnavailable: false
            )
        } catch {
            guard trigger == .backgroundMaintenance, isProtectedDataAccessFailure(error) else {
                throw error
            }
            let cachedPlan = buildTagQueryPlan(from: refreshTicketLedger, referenceDate: Date())
            return TagPlanResolution(
                plan: cachedPlan,
                usedCachedTickets: !cachedPlan.allTags.isEmpty,
                cachedTicketsUnavailable: cachedPlan.allTags.isEmpty
            )
        }
    }

    private func buildTagQueryPlan(
        from refreshTicketLedger: PIRRefreshTicketLedger?,
        referenceDate: Date
    ) -> TagQueryPlan {
        guard let refreshTicketLedger, refreshTicketLedger.expiresAt >= referenceDate else {
            return TagQueryPlan()
        }

        var plan = TagQueryPlan()
        for ticket in refreshTicketLedger.tickets where ticket.queryClass == .tagDiscovery {
            guard let tag = ticket.tag else {
                continue
            }
            if let relationshipID = ticket.relationshipID {
                let query = tachyonDiscoveryAdapter.makeRatchetedQuery(
                    tag: tag,
                    relationshipID: relationshipID,
                    lookaheadStep: ticket.lookaheadStep ?? 1
                )
                plan.queries.append(query)
                plan.relationshipByTagDigest[query.tagDigest] = (relationshipID, ticket.lookaheadStep ?? 1)
                continue
            }
            if let descriptorID = ticket.descriptorID {
                let query = tachyonDiscoveryAdapter.makeBootstrapQuery(tag: tag, descriptorID: descriptorID)
                plan.queries.append(query)
                plan.bootstrapDescriptorByTagDigest[query.tagDigest] = descriptorID
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

    private func resumeInterruptedInboxEntries(
        profile: inout WalletProfile,
        descriptorsByID: [UUID: PrivateReceiveDescriptor],
        checkpoint: ((WalletProfile) async throws -> Void)?
    ) async throws {
        let resumableEntries = profile.shielded.inboxJournal
            .filter { $0.stage == .payloadDecrypted || $0.stage == .payloadValidated }
            .sorted { $0.receivedAt < $1.receivedAt }

        for entry in resumableEntries {
            guard let descriptor = descriptorsByID[entry.descriptorID] else {
                updateInboxJournalEntry(
                    in: &profile,
                    id: entry.id,
                    stage: .failed,
                    detail: "Receive descriptor is no longer active; the interrupted note could not be resumed."
                )
                try await checkpoint?(profile)
                continue
            }

            guard let resumptionMaterial = entry.resumptionMaterial else {
                updateInboxJournalEntry(
                    in: &profile,
                    id: entry.id,
                    stage: .failed,
                    detail: "Receive journal entry is missing resumable note-ingestion context."
                )
                try await checkpoint?(profile)
                continue
            }

            switch entry.stage {
            case .payloadDecrypted:
                guard let payload = resumptionMaterial.decryptedPayload else {
                    updateInboxJournalEntry(
                        in: &profile,
                        id: entry.id,
                        stage: .failed,
                        detail: "Decrypted receive payload is unavailable for resumption."
                    )
                    try await checkpoint?(profile)
                    continue
                }
                try await continueMatchIngestion(
                    profile: &profile,
                    journalID: entry.id,
                    descriptor: descriptor,
                    matchedRelationshipID: entry.relationshipID,
                    lookaheadStep: resumptionMaterial.lookaheadStep,
                    tagDigest: entry.tagDigest,
                    ciphertextDigest: entry.ciphertextDigest,
                    payload: payload,
                    matchTag: resumptionMaterial.matchedTag,
                    senderIntroductionEncapsulatedKey: resumptionMaterial.senderIntroductionEncapsulatedKey,
                    receivedAt: entry.receivedAt,
                    checkpoint: checkpoint
                )
            case .payloadValidated:
                guard let decodedNote = resumptionMaterial.decodedNote else {
                    updateInboxJournalEntry(
                        in: &profile,
                        id: entry.id,
                        stage: .failed,
                        detail: "Validated note payload is unavailable for resumption."
                    )
                    try await checkpoint?(profile)
                    continue
                }
                try await insertDecodedNote(
                    profile: &profile,
                    journalID: entry.id,
                    descriptor: descriptor,
                    relationshipID: entry.relationshipID ?? decodedNote.relationshipID,
                    decodedNote: decodedNote,
                    checkpoint: checkpoint
                )
            default:
                continue
            }
        }
    }

    private func continueMatchIngestion(
        profile: inout WalletProfile,
        journalID: UUID,
        descriptor: PrivateReceiveDescriptor,
        matchedRelationshipID: UUID?,
        lookaheadStep: Int?,
        tagDigest: Data,
        ciphertextDigest: Data,
        payload: ShieldedRecipientPayload,
        matchTag: Data,
        senderIntroductionEncapsulatedKey: Data?,
        receivedAt: Date,
        checkpoint: ((WalletProfile) async throws -> Void)?
    ) async throws {
        guard !profile.shielded.notes.contains(where: { $0.noteCommitment == payload.noteCommitment }) else {
            clearInboxJournalResumptionMaterial(in: &profile, id: journalID)
            updateInboxJournalEntry(
                in: &profile,
                id: journalID,
                stage: .spendabilityClassified,
                noteCommitment: payload.noteCommitment,
                detail: "Duplicate note commitment ignored."
            )
            try await checkpoint?(profile)
            return
        }

        let relationshipID: UUID
        if let acceptedRelationshipID = acceptedRelationshipID(
            in: profile,
            ciphertextDigest: ciphertextDigest
        ) {
            relationshipID = acceptedRelationshipID
        } else {
            relationshipID = try await consumeIncomingMatch(
                profile: &profile,
                descriptor: descriptor,
                matchedRelationshipID: matchedRelationshipID,
                lookaheadStep: lookaheadStep,
                introductionEncapsulatedKey: senderIntroductionEncapsulatedKey,
                tagDigest: tagDigest,
                ciphertextDigest: ciphertextDigest
            )
        }

        let syntheticMatch = TaggedPaymentMatch(
            tag: matchTag,
            recipientDescriptorID: descriptor.id,
            noteCiphertext: Data(),
            senderIntroductionEncapsulatedKey: senderIntroductionEncapsulatedKey,
            receivedAt: receivedAt
        )
        let decodedNote = try tachyonStateAdapter.makeDecodedNote(
            from: payload,
            match: syntheticMatch,
            descriptor: descriptor,
            relationshipID: relationshipID
        )

        setInboxJournalResumptionMaterial(
            in: &profile,
            id: journalID,
            material: ShieldedInboxResumptionMaterial(
                matchedTag: matchTag,
                senderIntroductionEncapsulatedKey: senderIntroductionEncapsulatedKey,
                lookaheadStep: lookaheadStep,
                decryptedPayload: payload,
                decodedNote: decodedNote
            )
        )
        updateInboxJournalEntry(
            in: &profile,
            id: journalID,
            stage: .payloadValidated,
            relationshipID: relationshipID,
            noteCommitment: decodedNote.noteCommitment,
            detail: "Payload validated through the Tachyon state adapter."
        )
        try await checkpoint?(profile)

        try await insertDecodedNote(
            profile: &profile,
            journalID: journalID,
            descriptor: descriptor,
            relationshipID: relationshipID,
            decodedNote: decodedNote,
            checkpoint: checkpoint
        )
    }

    private func insertDecodedNote(
        profile: inout WalletProfile,
        journalID: UUID,
        descriptor: PrivateReceiveDescriptor,
        relationshipID: UUID?,
        decodedNote: TachyonDecodedNote,
        checkpoint: ((WalletProfile) async throws -> Void)?
    ) async throws {
        guard !profile.shielded.notes.contains(where: { $0.noteCommitment == decodedNote.noteCommitment }) else {
            clearInboxJournalResumptionMaterial(in: &profile, id: journalID)
            updateInboxJournalEntry(
                in: &profile,
                id: journalID,
                stage: .spendabilityClassified,
                relationshipID: relationshipID,
                noteCommitment: decodedNote.noteCommitment,
                detail: "Duplicate note commitment ignored."
            )
            try await checkpoint?(profile)
            return
        }

        let note = ShieldedNoteWitness(
            id: UUID(),
            tier: descriptor.tier,
            noteCommitment: decodedNote.noteCommitment,
            nullifier: decodedNote.nullifier,
            amount: decodedNote.amount,
            memo: decodedNote.memo,
            receivedAt: decodedNote.receivedAt,
            descriptorID: decodedNote.descriptorID,
            relationshipID: decodedNote.relationshipID,
            latestTag: decodedNote.latestTag,
            merklePath: nil,
            lastMerkleUpdateAt: nil,
            lastNullifierCheckAt: nil,
            readinessState: .discovered,
            spendState: .ready
        )
        profile.shielded.notes.append(note)
        clearInboxJournalResumptionMaterial(in: &profile, id: journalID)
        updateInboxJournalEntry(
            in: &profile,
            id: journalID,
            stage: .noteInserted,
            relationshipID: relationshipID,
            noteID: note.id,
            noteCommitment: note.noteCommitment,
            detail: "Note inserted into shielded state as discovered."
        )
        try await checkpoint?(profile)
    }

    private func consumeIncomingMatch(
        profile: inout WalletProfile,
        descriptor: PrivateReceiveDescriptor,
        matchedRelationshipID: UUID?,
        lookaheadStep: Int?,
        introductionEncapsulatedKey: Data?,
        tagDigest: Data,
        ciphertextDigest: Data
    ) async throws -> UUID {
        if let matchedRelationshipID,
           let index = profile.shielded.relationships.firstIndex(where: { $0.id == matchedRelationshipID }) {
            var relationship = profile.shielded.relationships[index]
            var secrets = try await ratchetSecretStore.load(relationshipID: relationship.id)
            let steps = max(lookaheadStep ?? 1, 1)
            for _ in 0..<steps {
                let ratcheted = tagRatchetEngine.advanceIncomingTag(using: secrets)
                secrets.incomingChainKey = ratcheted.updatedChainKey
            }
            relationship.nextIncomingCounter += UInt64(steps)
            relationship.lastIssuedIncomingLookaheadCounter = relationship.nextIncomingCounter + UInt64(max(relationship.lookaheadWindowSize, 1))
            relationship.lastAcceptedIncomingTagDigest = tagDigest
            recordAcceptedIncomingReplayEvidence(
                for: &relationship,
                tagDigest: tagDigest,
                ciphertextDigest: ciphertextDigest
            )
            relationship.lastActivityAt = Date()
            relationship.direction = reconciledDirection(for: relationship)
            relationship.state = acceptedIncomingState(for: relationship)
            profile.shielded.relationships[index] = relationship
            try await ratchetSecretStore.store(secrets, relationshipID: relationship.id)
            return relationship.id
        }

        if matchedRelationshipID != nil {
            throw WalletError.invalidShieldedPayload("Matched relationship cursor is unavailable for the received tag.")
        }

        guard let introductionEncapsulatedKey else {
            throw WalletError.invalidShieldedPayload("Bootstrap receive is missing sender introduction material.")
        }

        let descriptorMaterial = try await descriptorSecretStore.load(descriptorID: descriptor.id, tier: descriptor.tier)
        let derived = try tagRatchetEngine.deriveRecipientRelationship(
            alias: descriptor.aliasHint,
            descriptor: descriptor,
            descriptorSecrets: descriptorMaterial,
            introductionEncapsulatedKey: introductionEncapsulatedKey
        )
        var relationship = derived.snapshot
        var secrets = derived.secrets
        let ratcheted = tagRatchetEngine.advanceIncomingTag(using: secrets)
        secrets.incomingChainKey = ratcheted.updatedChainKey
        relationship.nextIncomingCounter = 1
        relationship.lastIssuedIncomingLookaheadCounter = relationship.nextIncomingCounter + UInt64(max(relationship.lookaheadWindowSize, 1))
        relationship.lastAcceptedIncomingTagDigest = tagDigest
        recordAcceptedIncomingReplayEvidence(
            for: &relationship,
            tagDigest: tagDigest,
            ciphertextDigest: ciphertextDigest
        )
        relationship.lastActivityAt = Date()
        relationship.direction = reconciledDirection(for: relationship)
        relationship.state = acceptedIncomingState(for: relationship)
        profile.shielded.relationships.append(relationship)
        try await ratchetSecretStore.store(secrets, relationshipID: relationship.id)
        return relationship.id
    }

    private func approximateEnvelopeBytes(for payloads: [Data]) -> Int {
        payloads.reduce(0) { partialResult, payload in
            partialResult + payload.count + 96
        }
    }

    private func acceptedRelationshipID(
        in profile: WalletProfile,
        ciphertextDigest: Data
    ) -> UUID? {
        profile.shielded.relationships.first { relationship in
            relationship.acceptedCiphertextDigests.contains(ciphertextDigest)
        }?.id
    }

    private func upsertInboxJournalEntry(
        in profile: inout WalletProfile,
        entry: ShieldedInboxJournalEntry
    ) -> UUID {
        if let index = profile.shielded.inboxJournal.firstIndex(where: {
            $0.ciphertextDigest == entry.ciphertextDigest && $0.tagDigest == entry.tagDigest
        }) {
            profile.shielded.inboxJournal[index].stage = entry.stage
            profile.shielded.inboxJournal[index].descriptorID = entry.descriptorID
            profile.shielded.inboxJournal[index].relationshipID = entry.relationshipID ?? profile.shielded.inboxJournal[index].relationshipID
            profile.shielded.inboxJournal[index].updatedAt = entry.updatedAt
            profile.shielded.inboxJournal[index].detail = entry.detail
            if let resumptionMaterial = entry.resumptionMaterial {
                profile.shielded.inboxJournal[index].resumptionMaterial = resumptionMaterial
            }
            if entry.receivedAt < profile.shielded.inboxJournal[index].receivedAt {
                profile.shielded.inboxJournal[index].receivedAt = entry.receivedAt
            }
            return profile.shielded.inboxJournal[index].id
        }
        profile.shielded.inboxJournal.append(entry)
        trimInboxJournal(in: &profile)
        return entry.id
    }

    private func updateInboxJournalEntry(
        in profile: inout WalletProfile,
        id: UUID,
        stage: ShieldedInboxJournalStage,
        relationshipID: UUID? = nil,
        noteID: UUID? = nil,
        noteCommitment: Data? = nil,
        detail: String? = nil
    ) {
        guard let index = profile.shielded.inboxJournal.firstIndex(where: { $0.id == id }) else {
            return
        }
        profile.shielded.inboxJournal[index].stage = stage
        profile.shielded.inboxJournal[index].relationshipID = relationshipID ?? profile.shielded.inboxJournal[index].relationshipID
        profile.shielded.inboxJournal[index].noteID = noteID ?? profile.shielded.inboxJournal[index].noteID
        profile.shielded.inboxJournal[index].noteCommitment = noteCommitment ?? profile.shielded.inboxJournal[index].noteCommitment
        profile.shielded.inboxJournal[index].updatedAt = Date()
        profile.shielded.inboxJournal[index].detail = detail
    }

    private func setInboxJournalResumptionMaterial(
        in profile: inout WalletProfile,
        id: UUID,
        material: ShieldedInboxResumptionMaterial
    ) {
        guard let index = profile.shielded.inboxJournal.firstIndex(where: { $0.id == id }) else {
            return
        }
        profile.shielded.inboxJournal[index].resumptionMaterial = material
        profile.shielded.inboxJournal[index].updatedAt = Date()
    }

    private func clearInboxJournalResumptionMaterial(
        in profile: inout WalletProfile,
        id: UUID
    ) {
        guard let index = profile.shielded.inboxJournal.firstIndex(where: { $0.id == id }) else {
            return
        }
        profile.shielded.inboxJournal[index].resumptionMaterial = nil
        profile.shielded.inboxJournal[index].updatedAt = Date()
    }

    private func updateInboxJournalEntries(
        in profile: inout WalletProfile,
        matching noteCommitment: Data,
        stage: ShieldedInboxJournalStage,
        noteID: UUID,
        detail: String
    ) {
        for index in profile.shielded.inboxJournal.indices where profile.shielded.inboxJournal[index].noteCommitment == noteCommitment {
            profile.shielded.inboxJournal[index].stage = stage
            profile.shielded.inboxJournal[index].noteID = noteID
            profile.shielded.inboxJournal[index].resumptionMaterial = nil
            profile.shielded.inboxJournal[index].updatedAt = Date()
            profile.shielded.inboxJournal[index].detail = detail
        }
    }

    private func trimInboxJournal(in profile: inout WalletProfile, limit: Int = 128) {
        guard profile.shielded.inboxJournal.count > limit else {
            return
        }
        profile.shielded.inboxJournal.removeFirst(profile.shielded.inboxJournal.count - limit)
    }

    private func refreshRelationshipStates(in profile: inout WalletProfile, referenceDate: Date) {
        for index in profile.shielded.relationships.indices {
            guard profile.shielded.relationships[index].state != .revoked else {
                continue
            }
            let relationship = profile.shielded.relationships[index]
            let activityDate = relationship.lastActivityAt ?? relationship.establishedAt
            if referenceDate.timeIntervalSince(activityDate) > relationshipStaleInterval {
                profile.shielded.relationships[index].state = .stale
                continue
            }
            if relationship.state == .stale {
                profile.shielded.relationships[index].state = inferredActiveState(for: relationship)
            }
        }
    }

    private func isReplayMatch(
        profile: WalletProfile,
        relationshipID: UUID?,
        tagDigest: Data,
        ciphertextDigest: Data
    ) -> Bool {
        if let relationshipID,
           let relationship = profile.shielded.relationships.first(where: { $0.id == relationshipID }) {
            return relationship.acceptedIncomingTagDigests.contains(tagDigest)
                || relationship.acceptedCiphertextDigests.contains(ciphertextDigest)
        }

        if profile.shielded.relationships.contains(where: { $0.acceptedCiphertextDigests.contains(ciphertextDigest) }) {
            return true
        }

        return profile.shielded.inboxJournal.contains(where: {
            $0.ciphertextDigest == ciphertextDigest
                && ($0.stage == .noteInserted
                    || $0.stage == .witnessRefreshed
                    || $0.stage == .spendabilityClassified)
        })
    }

    private func recordAcceptedIncomingReplayEvidence(
        for relationship: inout TagRelationshipSnapshot,
        tagDigest: Data,
        ciphertextDigest: Data
    ) {
        relationship.acceptedIncomingTagDigests = trimDigestWindow(
            relationship.acceptedIncomingTagDigests + [tagDigest]
        )
        relationship.acceptedCiphertextDigests = trimDigestWindow(
            relationship.acceptedCiphertextDigests + [ciphertextDigest]
        )
    }

    private func trimDigestWindow(_ digests: [Data], limit: Int = 32) -> [Data] {
        let uniqueDigests = Array(NSOrderedSet(array: digests)) as? [Data] ?? digests
        guard uniqueDigests.count > limit else {
            return uniqueDigests
        }
        return Array(uniqueDigests.suffix(limit))
    }

    private func preparedOutgoingState(
        for relationship: TagRelationshipSnapshot,
        isIntroductionPayment: Bool
    ) -> TagRelationshipState {
        if relationship.state == .revoked {
            return .revoked
        }
        if relationship.rotationTargetDescriptorID != nil {
            return .rotationPending
        }
        if relationship.nextIncomingCounter > 0 {
            return .activeBidirectional
        }
        if isIntroductionPayment || relationship.introductionEncapsulatedKey != nil {
            return .introductionSent
        }
        return .bootstrapPending
    }

    private func submittedOutgoingState(
        for relationship: TagRelationshipSnapshot,
        isIntroductionPayment: Bool
    ) -> TagRelationshipState {
        preparedOutgoingState(for: relationship, isIntroductionPayment: isIntroductionPayment)
    }

    private func acceptedIncomingState(for relationship: TagRelationshipSnapshot) -> TagRelationshipState {
        if relationship.state == .revoked {
            return .revoked
        }
        if relationship.rotationTargetDescriptorID != nil {
            return .rotationPending
        }
        if relationship.nextOutgoingCounter > 0 {
            return .activeBidirectional
        }
        return .introductionReceived
    }

    private func reconciledDirection(for relationship: TagRelationshipSnapshot) -> TagRelationshipDirection {
        if relationship.nextOutgoingCounter > 0 && relationship.nextIncomingCounter > 0 {
            return .bidirectional
        }
        if relationship.nextIncomingCounter > 0 {
            return .inbound
        }
        return .outbound
    }

    private func inferredActiveState(for relationship: TagRelationshipSnapshot) -> TagRelationshipState {
        if relationship.rotationTargetDescriptorID != nil {
            return .rotationPending
        }
        if relationship.nextOutgoingCounter > 0 && relationship.nextIncomingCounter > 0 {
            return .activeBidirectional
        }
        if relationship.nextIncomingCounter > 0 {
            return .introductionReceived
        }
        if relationship.nextOutgoingCounter > 0 {
            return .introductionSent
        }
        return .bootstrapPending
    }

    private func makeRefreshTicketLedger(
        profile: WalletProfile,
        tagPlan: TagQueryPlan,
        generatedAt: Date
    ) -> PIRRefreshTicketLedger {
        let expiresAt = generatedAt.addingTimeInterval(refreshTicketLifetime)
        var tickets: [PIRRefreshTicket] = []

        for query in tagPlan.queries {
            let relationshipInfo = tagPlan.relationshipByTagDigest[query.tagDigest]
            let descriptorID = tagPlan.bootstrapDescriptorByTagDigest[query.tagDigest]
            tickets.append(
                makeRefreshTicket(
                    queryClass: .tagDiscovery,
                    descriptorID: descriptorID,
                    relationshipID: relationshipInfo?.relationshipID,
                    noteID: nil,
                    noteCommitment: nil,
                    nullifier: nil,
                    tag: query.tag,
                    lookaheadStep: relationshipInfo?.steps,
                    createdAt: generatedAt,
                    expiresAt: expiresAt
                )
            )
        }

        for note in profile.shielded.notes where note.spendState != .spent {
            tickets.append(
                makeRefreshTicket(
                    queryClass: .nullifierStatuses,
                    descriptorID: note.descriptorID,
                    relationshipID: note.relationshipID,
                    noteID: note.id,
                    noteCommitment: nil,
                    nullifier: note.nullifier,
                    tag: nil,
                    lookaheadStep: nil,
                    createdAt: generatedAt,
                    expiresAt: expiresAt
                )
            )
            tickets.append(
                makeRefreshTicket(
                    queryClass: .merklePaths,
                    descriptorID: note.descriptorID,
                    relationshipID: note.relationshipID,
                    noteID: note.id,
                    noteCommitment: note.noteCommitment,
                    nullifier: nil,
                    tag: nil,
                    lookaheadStep: nil,
                    createdAt: generatedAt,
                    expiresAt: expiresAt
                )
            )
        }

        let timingMaterial = Data("\(generatedAt.timeIntervalSince1970)|\(expiresAt.timeIntervalSince1970)".utf8)
        let digest = TachyonSupport.digest([timingMaterial] + tickets.map(\.ticketDigest))
        return PIRRefreshTicketLedger(
            generatedAt: generatedAt,
            expiresAt: expiresAt,
            tickets: tickets,
            digest: digest
        )
    }

    private func makeRefreshTicket(
        queryClass: PIRQueryClass,
        descriptorID: UUID?,
        relationshipID: UUID?,
        noteID: UUID?,
        noteCommitment: Data?,
        nullifier: Data?,
        tag: Data?,
        lookaheadStep: Int?,
        createdAt: Date,
        expiresAt: Date
    ) -> PIRRefreshTicket {
        let ticketDigest = TachyonSupport.digest(
            Data(queryClass.rawValue.utf8),
            data(for: descriptorID),
            data(for: relationshipID),
            data(for: noteID),
            noteCommitment ?? Data(),
            nullifier ?? Data(),
            tag ?? Data(),
            data(for: lookaheadStep)
        )
        return PIRRefreshTicket(
            id: UUID(),
            queryClass: queryClass,
            ticketDigest: ticketDigest,
            descriptorID: descriptorID,
            relationshipID: relationshipID,
            noteID: noteID,
            noteCommitment: noteCommitment,
            nullifier: nullifier,
            tag: tag,
            lookaheadStep: lookaheadStep,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    private func makeQueryReceipt(
        from transportReceipt: PIRTransportReceipt,
        blockHeight: UInt64,
        responseItemCount: Int,
        anchorRoot: Data? = nil
    ) -> PIRQueryReceipt {
        PIRQueryReceipt(
            id: UUID(),
            queryClass: transportReceipt.queryClass,
            providerID: transportReceipt.provider.id,
            requestDigest: transportReceipt.requestDigest,
            responseDigest: transportReceipt.responseDigest,
            responseItemCount: responseItemCount,
            blockHeight: blockHeight,
            anchorRoot: anchorRoot,
            receivedAt: transportReceipt.receivedAt
        )
    }

    private func makeMismatchEvent(
        queryClass: PIRQueryClass,
        providerIDs: [String],
        reason: String,
        expectedDigest: Data? = nil,
        observedDigest: Data? = nil,
        expectedBlockHeight: UInt64? = nil,
        observedBlockHeight: UInt64? = nil
    ) -> PIRMismatchEvent {
        PIRMismatchEvent(
            id: UUID(),
            queryClass: queryClass,
            providerIDs: providerIDs,
            reason: reason,
            expectedDigest: expectedDigest,
            observedDigest: observedDigest,
            expectedBlockHeight: expectedBlockHeight,
            observedBlockHeight: observedBlockHeight,
            recordedAt: Date()
        )
    }

    private func makeDisputeEvidence(
        receipts: [PIRQueryReceipt],
        mismatchEvents: [PIRMismatchEvent],
        notes: [ShieldedNoteWitness],
        tagPlan: TagQueryPlan,
        capturedAt: Date
    ) -> PIRDisputeEvidenceSnapshot {
        PIRDisputeEvidenceSnapshot(
            capturedAt: capturedAt,
            queryReceipts: receipts,
            mismatchEvents: mismatchEvents,
            noteCommitmentDigests: notes.map { TachyonSupport.digest($0.noteCommitment) },
            nullifierDigests: notes.map { TachyonSupport.digest($0.nullifier) },
            tagDigests: tagPlan.queries.map(\.tagDigest)
        )
    }

    private func makeReadinessLease(
        classification: PIRReadinessClassification,
        priorLease: PIRReadinessLease?,
        trustedBlockHeight: UInt64,
        anchorRoot: Data?,
        providerIDs: [String],
        ticketLedger: PIRRefreshTicketLedger,
        evidence: PIRDisputeEvidenceSnapshot?,
        issuedAt: Date,
        detail: String
    ) -> PIRReadinessLease {
        let expiresAt: Date
        switch classification {
        case .ready:
            expiresAt = issuedAt.addingTimeInterval(readinessLeaseLifetime)
        case .stale:
            expiresAt = priorLease?.expiresAt ?? issuedAt
        case .degraded, .disputed:
            expiresAt = priorLease?.expiresAt ?? issuedAt
        }
        return PIRReadinessLease(
            classification: classification,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            trustedBlockHeight: trustedBlockHeight,
            anchorRoot: anchorRoot,
            providerIDs: providerIDs,
            ticketLedgerDigest: ticketLedger.digest,
            evidenceDigest: evidence.map(digestForEvidence),
            detail: detail
        )
    }

    private func digestForEvidence(_ evidence: PIRDisputeEvidenceSnapshot) -> Data {
        let mismatchDigests = evidence.mismatchEvents.map { event in
            TachyonSupport.digest(
                Data(event.queryClass.rawValue.utf8),
                Data(event.providerIDs.joined(separator: "|").utf8),
                Data(event.reason.utf8),
                event.expectedDigest ?? Data(),
                event.observedDigest ?? Data(),
                Data(String(event.expectedBlockHeight ?? 0).utf8),
                Data(String(event.observedBlockHeight ?? 0).utf8)
            )
        }
        return TachyonSupport.digest(
            evidence.noteCommitmentDigests
                + evidence.nullifierDigests
                + evidence.tagDigests
                + evidence.queryReceipts.map(\.responseDigest)
                + mismatchDigests
        )
    }

    private func trimReceipts(_ receipts: [PIRQueryReceipt], limit: Int = 24) -> [PIRQueryReceipt] {
        guard receipts.count > limit else {
            return receipts
        }
        return Array(receipts.suffix(limit))
    }

    private func trimMismatchEvents(_ mismatchEvents: [PIRMismatchEvent], limit: Int = 24) -> [PIRMismatchEvent] {
        guard mismatchEvents.count > limit else {
            return mismatchEvents
        }
        return Array(mismatchEvents.suffix(limit))
    }

    private func combineReadinessClassification(
        _ current: PIRReadinessClassification,
        _ candidate: PIRReadinessClassification
    ) -> PIRReadinessClassification {
        readinessPriority(candidate) > readinessPriority(current) ? candidate : current
    }

    private func readinessPriority(_ classification: PIRReadinessClassification) -> Int {
        switch classification {
        case .ready:
            return 0
        case .stale:
            return 1
        case .degraded:
            return 2
        case .disputed:
            return 3
        }
    }

    private func isProtectedDataAccessFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSOSStatusErrorDomain else {
            return false
        }
        return nsError.code == Int(errSecInteractionNotAllowed)
            || nsError.code == Int(errSecNotAvailable)
            || nsError.code == Int(errSecAuthFailed)
    }

    private func data(for uuid: UUID?) -> Data {
        guard let uuid else {
            return Data()
        }
        return Data(uuid.uuidString.utf8)
    }

    private func data(for int: Int?) -> Data {
        guard let int else {
            return Data()
        }
        return Data(String(int).utf8)
    }

    private var refreshTicketLifetime: TimeInterval {
        max(configuration.batchWindow * 16, 15 * 60)
    }

    private var readinessLeaseLifetime: TimeInterval {
        max(configuration.batchWindow * 20, 20 * 60)
    }

    private var relationshipStaleInterval: TimeInterval {
        max(configuration.batchWindow * 2_880, 30 * 24 * 60 * 60)
    }

    private func classifyReadiness(for note: ShieldedNoteWitness) -> ShieldedNoteReadinessState {
        if note.spendState == .ready, note.merklePath != nil, note.lastMerkleUpdateAt != nil {
            return .immediatelySpendable
        }
        if note.merklePath != nil {
            return .witnessFresh
        }
        if note.lastNullifierCheckAt != nil {
            return .verified
        }
        return .discovered
    }

    private func detailForReadinessState(_ state: ShieldedNoteReadinessState) -> String {
        switch state {
        case .discovered:
            return "Discovered note is awaiting nullifier verification."
        case .verified:
            return "Nullifier check passed; witness refresh still required."
        case .witnessFresh:
            return "Witness refreshed, but note is not immediately spendable."
        case .immediatelySpendable:
            return "Note is immediately spendable with fresh witness data."
        }
    }
}

private struct TagPlanResolution {
    var plan: TagQueryPlan
    var usedCachedTickets: Bool
    var cachedTicketsUnavailable: Bool
}

private struct TagQueryPlan {
    var queries: [TachyonDiscoveryQuery] = []
    var bootstrapDescriptorByTagDigest: [Data: UUID] = [:]
    var relationshipByTagDigest: [Data: (relationshipID: UUID, steps: Int)] = [:]

    var allTags: [Data] {
        queries.map(\.tag)
    }
}
