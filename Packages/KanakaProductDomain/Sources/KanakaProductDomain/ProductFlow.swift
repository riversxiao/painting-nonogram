import Foundation
import KanakaContentKit
import KanakaCore
import KanakaProgress
import KanakaStory

public struct ProductFlow: Sendable {
    public let id: UUID
    public let artworkStates: ArtworkStateService
    public let blueprints: BlueprintUseService

    private let catalog: RuntimeContentCatalog
    private let progressStore: any ProgressStore
    private let storyProcessor: StoryEventProcessor
    private let storyMapping: CompletionStoryMapping
    private let throttleDelay: Duration

    public init(
        catalog: RuntimeContentCatalog,
        progressStore: any ProgressStore,
        storyProcessor: StoryEventProcessor,
        storyMapping: CompletionStoryMapping,
        throttleDelay: Duration = .milliseconds(300)
    ) throws {
        try Self.validateStoryMapping(
            storyMapping,
            catalog: catalog,
            rules: storyProcessor.rules
        )
        id = UUID()
        self.catalog = catalog
        self.progressStore = progressStore
        self.storyProcessor = storyProcessor
        self.storyMapping = storyMapping
        self.throttleDelay = throttleDelay
        artworkStates = ArtworkStateService(catalog: catalog, progressStore: progressStore)
        blueprints = BlueprintUseService(artworkStateService: artworkStates)
    }

    public func openFragment(_ fragmentID: String) async throws -> PuzzleSessionController {
        let context = try catalog.fragmentContext(id: fragmentID)
        let keys = try catalog.currentFragmentIdentities(artworkID: context.artwork.id).map(Self.progressKey)
        let opened = try await ProgressSessionLoader.open(
            fragmentID: fragmentID,
            puzzle: context.puzzle,
            store: progressStore
        )
        let session: GameSession
        let generation: UInt64
        switch opened {
        case .new(let value, let valueGeneration), .restored(let value, let valueGeneration):
            session = value
            generation = valueGeneration
        case .requiresMigration(_, let mismatch):
            throw ProductDomainError.migrationRequired(String(describing: mismatch))
        case .corrupt(_, let reason):
            throw ProductDomainError.corruptProgress(String(describing: reason))
        }
        let finalized = try await progressStore.record(
            for: ProgressRecordKey(fragmentID: fragmentID, puzzle: context.puzzle)
        )?.completedAt != nil
        return try PuzzleSessionController(
            flowID: id,
            fragmentID: fragmentID,
            artworkID: context.artwork.id,
            puzzle: context.puzzle,
            requiredFragmentKeys: keys,
            session: session,
            generation: generation,
            finalized: finalized,
            progressStore: progressStore,
            throttleDelay: throttleDelay
        )
    }

    public func complete(
        _ controller: PuzzleSessionController,
        entitlements: MuseumEntitlementSnapshot = MuseumEntitlementSnapshot(),
        completedAt: Date = Date()
    ) async throws -> FragmentCompletionOutcome {
        guard controller.flowID == id else { throw ProductDomainError.sessionBelongsToAnotherFlow }
        let receipt = try await controller.complete(completedAt: completedAt)
        let artworkState = try artworkStates.state(
            artworkID: controller.artworkID,
            completionReceipt: receipt,
            entitlements: entitlements
        )
        let decisions = try await reconcileStory()
        return FragmentCompletionOutcome(
            receipt: receipt,
            artworkState: artworkState,
            storyDecisions: decisions
        )
    }

    /// Rebuilds completion evidence for the whole catalog from one exact-current progress snapshot.
    /// Candidates are submitted in Story rule order so previously completed later content converges
    /// when an earlier durable prerequisite becomes available.
    public func reconcileStory() async throws -> [StoryTransitionDecision] {
        let candidates = try await completionEvidenceCandidates()
        let state = try await storyProcessor.state()
        let acceptedCount = state.acceptedEvidence.count
        var decisions: [StoryTransitionDecision] = []

        for (index, rule) in storyProcessor.rules.orderedEvidence.enumerated() {
            guard let envelope = candidates[rule.evidenceID] else {
                if index < acceptedCount { continue }
                break
            }
            let decision = try await storyProcessor.submit(envelope)
            decisions.append(decision)
            switch decision {
            case .applied, .alreadyApplied:
                continue
            case .rejected:
                return decisions
            }
        }
        return decisions
    }

    public func recordNarrativeAction(
        occurrenceID: String,
        evidenceID: StoryEvidenceID,
        referenceID: String,
        occurredAt: Date = Date()
    ) async throws -> StoryTransitionDecision {
        try requireRule(evidenceID, sourceKind: .narrativeAction)
        let decision = try await storyProcessor.submit(StoryEvidenceEnvelope(
            occurrenceID: StoryEvidenceOccurrenceID(rawValue: occurrenceID),
            evidenceID: evidenceID,
            source: StoryEvidenceSource(kind: .narrativeAction, referenceID: referenceID),
            occurredAt: occurredAt,
            rulesRevision: storyProcessor.rules.revision
        ))
        if Self.wasAccepted(decision) { _ = try await reconcileStory() }
        return decision
    }

    public func recordBridgeSessionEvidence(
        occurrenceID: String,
        evidenceID: StoryEvidenceID,
        referenceID: String,
        sessionID: String,
        occurredAt: Date = Date()
    ) async throws -> StoryTransitionDecision {
        guard !sessionID.isEmpty else {
            throw ProductDomainError.invalidStoryMapping("bridge session ID must not be empty")
        }
        try requireRule(evidenceID, sourceKind: .bridgeSession)
        let decision = try await storyProcessor.submit(StoryEvidenceEnvelope(
            occurrenceID: StoryEvidenceOccurrenceID(rawValue: occurrenceID),
            evidenceID: evidenceID,
            source: StoryEvidenceSource(
                kind: .bridgeSession,
                referenceID: referenceID,
                sessionID: sessionID
            ),
            occurredAt: occurredAt,
            rulesRevision: storyProcessor.rules.revision
        ))
        if Self.wasAccepted(decision) { _ = try await reconcileStory() }
        return decision
    }

    public func storyState() async throws -> StoryState {
        try await storyProcessor.state()
    }

    private func completionEvidenceCandidates() async throws -> [StoryEvidenceID: StoryEvidenceEnvelope] {
        var keysByFragmentID: [String: ProgressRecordKey] = [:]
        var orderedKeysByArtworkID: [String: [ProgressRecordKey]] = [:]

        for artworkID in catalog.artworks.keys.sorted() {
            let keys = try catalog.currentFragmentIdentities(artworkID: artworkID).map(Self.progressKey)
            orderedKeysByArtworkID[artworkID] = keys
            for key in keys { keysByFragmentID[key.fragmentID] = key }
        }

        let records = try await progressStore.records(for: Set(keysByFragmentID.values))
        var candidates: [StoryEvidenceID: StoryEvidenceEnvelope] = [:]

        for (fragmentID, evidenceID) in storyMapping.fragmentEvidence {
            guard let key = keysByFragmentID[fragmentID],
                  let completedAt = records[key]?.completedAt else { continue }
            candidates[evidenceID] = StoryEvidenceEnvelope(
                occurrenceID: Self.occurrenceID(kind: "fragment", subjectID: fragmentID, keys: [key]),
                evidenceID: evidenceID,
                source: StoryEvidenceSource(kind: .fragmentCompletion, referenceID: fragmentID),
                occurredAt: completedAt,
                rulesRevision: storyProcessor.rules.revision
            )
        }

        for (artworkID, evidenceID) in storyMapping.artworkEvidence {
            guard let keys = orderedKeysByArtworkID[artworkID] else { continue }
            let timestamps = keys.compactMap { records[$0]?.completedAt }
            guard timestamps.count == keys.count, let restoredAt = timestamps.max() else { continue }
            candidates[evidenceID] = StoryEvidenceEnvelope(
                occurrenceID: Self.occurrenceID(kind: "artwork", subjectID: artworkID, keys: keys),
                evidenceID: evidenceID,
                source: StoryEvidenceSource(kind: .artworkRestoration, referenceID: artworkID),
                occurredAt: restoredAt,
                rulesRevision: storyProcessor.rules.revision
            )
        }
        return candidates
    }

    private func requireRule(
        _ evidenceID: StoryEvidenceID,
        sourceKind: StoryEvidenceSourceKind
    ) throws {
        guard let rule = storyProcessor.rules.orderedEvidence.first(where: { $0.evidenceID == evidenceID }),
              rule.sourceKind == sourceKind else {
            throw ProductDomainError.invalidStoryMapping(
                "evidence \(evidenceID.rawValue) is not configured for \(sourceKind.rawValue)"
            )
        }
    }

    private static func validateStoryMapping(
        _ mapping: CompletionStoryMapping,
        catalog: RuntimeContentCatalog,
        rules: StoryRuleSet
    ) throws {
        let rulesByID = Dictionary(uniqueKeysWithValues: rules.orderedEvidence.map { ($0.evidenceID, $0) })
        var mappedEvidence = Set<StoryEvidenceID>()

        for (fragmentID, evidenceID) in mapping.fragmentEvidence {
            guard catalog.fragments[fragmentID] != nil else {
                throw ProductDomainError.invalidStoryMapping("unknown Fragment \(fragmentID)")
            }
            guard let rule = rulesByID[evidenceID], rule.sourceKind == .fragmentCompletion else {
                throw ProductDomainError.invalidStoryMapping(
                    "Fragment \(fragmentID) maps to non-Fragment evidence \(evidenceID.rawValue)"
                )
            }
            guard mappedEvidence.insert(evidenceID).inserted else {
                throw ProductDomainError.invalidStoryMapping("evidence \(evidenceID.rawValue) is mapped more than once")
            }
        }

        for (artworkID, evidenceID) in mapping.artworkEvidence {
            guard catalog.artworks[artworkID] != nil else {
                throw ProductDomainError.invalidStoryMapping("unknown Artwork \(artworkID)")
            }
            guard let rule = rulesByID[evidenceID], rule.sourceKind == .artworkRestoration else {
                throw ProductDomainError.invalidStoryMapping(
                    "Artwork \(artworkID) maps to non-Artwork evidence \(evidenceID.rawValue)"
                )
            }
            guard mappedEvidence.insert(evidenceID).inserted else {
                throw ProductDomainError.invalidStoryMapping("evidence \(evidenceID.rawValue) is mapped more than once")
            }
        }
    }

    private static func progressKey(_ identity: CurrentFragmentIdentity) -> ProgressRecordKey {
        ProgressRecordKey(
            fragmentID: identity.fragmentID,
            puzzleID: identity.puzzleID,
            puzzleRevision: identity.puzzleRevision,
            puzzleSemanticHash: identity.puzzleSemanticHash
        )
    }

    /// Versioned, length-prefixed canonical bytes prevent delimiter ambiguity. The digest includes
    /// every exact progress identity field, including puzzle ID.
    private static func occurrenceID(
        kind: String,
        subjectID: String,
        keys: [ProgressRecordKey]
    ) -> StoryEvidenceOccurrenceID {
        var canonical = Data()
        for field in ["completion-occurrence-v1", kind, subjectID, String(keys.count)] {
            append(field, to: &canonical)
        }
        for key in keys {
            append(key.fragmentID, to: &canonical)
            append(key.puzzleID, to: &canonical)
            append(String(key.puzzleRevision), to: &canonical)
            append(key.puzzleSemanticHash, to: &canonical)
        }
        return StoryEvidenceOccurrenceID(
            rawValue: "\(kind):v1:sha256:\(SHA256.hexDigest(canonical))"
        )
    }

    private static func append(_ value: String, to data: inout Data) {
        let bytes = Data(value.utf8)
        var length = UInt64(bytes.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(bytes)
    }

    private static func wasAccepted(_ decision: StoryTransitionDecision) -> Bool {
        switch decision {
        case .applied, .alreadyApplied: true
        case .rejected: false
        }
    }
}
