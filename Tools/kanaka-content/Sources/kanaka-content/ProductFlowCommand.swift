import Foundation
import KanakaContentKit
import KanakaCore
import KanakaProductDomain
import KanakaProgress
import KanakaStory

func validateProductFlow(directoryURL: URL) async throws {
    let catalog = try RuntimeContentCatalog.loadValidated(directoryURL: directoryURL)
    guard catalog.museums.count == 1,
          catalog.artworks.count == 4,
          catalog.fragments.count == 10,
          catalog.productionAssetCounts.blueprints == 4,
          catalog.productionAssetCounts.beadPatterns == 4 else {
        throw CommandError.productValidationFailed("validated catalog counts are incorrect")
    }

    try validateProductionContentDefenses(directoryURL: directoryURL)
    try await validateMuseum1StoryRules()
    try await validateAtomicStoryStore()

    let artworkID = "dev-artwork-cardinality-2"
    let firstFragmentID = "dev-a2-f01"
    let secondFragmentID = "dev-a2-f02"
    let firstEvidence = StoryEvidenceID(rawValue: "dev.a2.fragment-1-completed")
    let secondEvidence = StoryEvidenceID(rawValue: "dev.a2.fragment-2-completed")
    let artworkEvidence = StoryEvidenceID(rawValue: "dev.a2.restored")
    let rules = try StoryRuleSet(
        id: "dev-product-flow-v1",
        revision: 1,
        orderedEvidence: [
            StoryEvidenceRule(evidenceID: firstEvidence, sourceKind: .fragmentCompletion),
            StoryEvidenceRule(evidenceID: secondEvidence, sourceKind: .fragmentCompletion),
            StoryEvidenceRule(
                evidenceID: artworkEvidence,
                sourceKind: .artworkRestoration,
                achievesMilestone: .technicalChainRestored
            ),
        ]
    )
    let progressStore = InMemoryProgressStore()
    let storyStore = InMemoryStoryStateStore()
    let storyProcessor = StoryEventProcessor(store: storyStore, rules: rules)
    let flow = try ProductFlow(
        catalog: catalog,
        progressStore: progressStore,
        storyProcessor: storyProcessor,
        storyMapping: CompletionStoryMapping(
            fragmentEvidence: [
                firstFragmentID: firstEvidence,
                secondFragmentID: secondEvidence,
            ],
            artworkEvidence: [artworkID: artworkEvidence]
        ),
        throttleDelay: .seconds(60)
    )
    try validateStoryMappingDefenses(catalog: catalog)

    let noEntitlement = MuseumEntitlementSnapshot()
    let museumEntitlement = MuseumEntitlementSnapshot(museumIDs: ["dev-museum-cardinality"])
    let initial = try await flow.artworkStates.state(
        artworkID: artworkID,
        entitlements: noEntitlement
    )
    guard initial.completedCount == 0,
          !initial.access.artworkRestored,
          !initial.access.canUseArtworkBlueprint,
          !initial.access.hasRestorerSeal else {
        throw CommandError.productValidationFailed("initial Artwork state is incorrect")
    }
    do {
        _ = try await flow.blueprints.openBlueprint(
            artworkID: artworkID,
            entitlements: noEntitlement
        )
        throw CommandError.productValidationFailed("locked Blueprint opened without entitlement")
    } catch ProductDomainError.blueprintAccessDenied {
        // Expected.
    }

    let entitledBlueprint = try await flow.blueprints.openBlueprint(
        artworkID: artworkID,
        entitlements: museumEntitlement
    )
    let entitledState = try await flow.artworkStates.state(
        artworkID: artworkID,
        entitlements: museumEntitlement
    )
    guard entitledBlueprint.exportPlan.pixelWidth == 16,
          entitledBlueprint.exportPlan.pixelHeight == 16,
          entitledState.access.canUseArtworkBlueprint,
          !entitledState.access.artworkRestored,
          !entitledState.access.hasRestorerSeal,
          try await flow.storyState().acceptedEvidence.isEmpty else {
        throw CommandError.productValidationFailed(
            "entitlement changed progress, seal, or Story instead of Blueprint access only"
        )
    }

    let firstController = try await flow.openFragment(firstFragmentID)
    try await solve(firstController, updatedAt: Date(timeIntervalSince1970: 100))
    try await firstController.flush()

    // Reopen through the catalog-driven service to prove mutation-triggered autosave and
    // durable current-identity restoration without a separate submit call.
    let resumedFirstController = try await flow.openFragment(firstFragmentID)
    guard await resumedFirstController.currentSession().isComplete else {
        throw CommandError.productValidationFailed("autosaved product session did not restore")
    }
    // Keep a second pre-completion controller alive to prove its higher generations cannot
    // replace the durable completion snapshot after another controller finalizes the record.
    let concurrentlyOpenedFirstController = try await flow.openFragment(firstFragmentID)

    // Complete the later Story evidence first. It remains durable but unapplied until the
    // earlier Fragment becomes available, proving catalog-wide deterministic convergence.
    let secondController = try await flow.openFragment(secondFragmentID)
    try await solve(secondController, updatedAt: Date(timeIntervalSince1970: 100.5))
    let outOfOrderOutcome = try await flow.complete(
        secondController,
        completedAt: Date(timeIntervalSince1970: 101)
    )
    guard outOfOrderOutcome.receipt.completedCount == 1,
          outOfOrderOutcome.receipt.totalCount == 2,
          outOfOrderOutcome.artworkState.completedCount == 1,
          !outOfOrderOutcome.artworkState.access.artworkRestored,
          try await flow.storyState().acceptedEvidence.isEmpty else {
        throw CommandError.productValidationFailed("out-of-order durable completion was not held at the Story gap")
    }

    let finalOutcome = try await flow.complete(
        resumedFirstController,
        completedAt: Date(timeIntervalSince1970: 102)
    )
    let finalStoryState = try await flow.storyState()
    guard finalOutcome.receipt.completedCount == 2,
          finalOutcome.receipt.totalCount == 2,
          finalOutcome.receipt.completedAtByFragmentKey.count == 2,
          finalOutcome.artworkState.completedCount == finalOutcome.receipt.completedCount,
          finalOutcome.artworkState.fragments.allSatisfy({ fragment in
              fragment.completedAt == finalOutcome.receipt.completedAtByFragmentKey[fragment.currentKey]
          }),
          finalOutcome.artworkState.access.artworkRestored,
          finalOutcome.artworkState.access.canUseArtworkBlueprint,
          finalOutcome.artworkState.access.hasRestorerSeal,
          finalStoryState.acceptedEvidence.map(\.evidenceID) == [
              firstEvidence, secondEvidence, artworkEvidence,
          ],
          finalStoryState.acceptedEvidence.last?.occurredAt == Date(timeIntervalSince1970: 102),
          finalStoryState.hasAchieved(.technicalChainRestored),
          finalStoryState.achievements.count == 1 else {
        throw CommandError.productValidationFailed("final atomic product outcome or global Story convergence is incorrect")
    }

    do {
        _ = try await resumedFirstController.apply([
            CellEdit(coordinate: CellCoordinate(x: 0, y: 0), state: .unknown),
        ])
        throw CommandError.productValidationFailed("completed controller accepted a mutation")
    } catch ProductDomainError.sessionFinalized {
        // Expected: completion records are immutable; replay must use a separate record.
    }

    _ = try await concurrentlyOpenedFirstController.apply([
        CellEdit(coordinate: CellCoordinate(x: 0, y: 0), state: .unknown),
    ])
    _ = try await concurrentlyOpenedFirstController.recordAssistance(.hint)
    do {
        try await concurrentlyOpenedFirstController.flush()
        throw CommandError.productValidationFailed(
            "pre-completion controller replaced a completed snapshot"
        )
    } catch ProgressStoreError.completedSnapshotImmutable {
        // Expected: higher generations may not change a completed snapshot.
    }

    let reopenedCompletedController = try await flow.openFragment(firstFragmentID)
    guard await reopenedCompletedController.isFinalized(),
          await reopenedCompletedController.currentSession().isComplete else {
        throw CommandError.productValidationFailed("reopened completed controller was not read-only and complete")
    }
    do {
        _ = try await reopenedCompletedController.undo()
        throw CommandError.productValidationFailed("reopened completed controller accepted undo")
    } catch ProductDomainError.sessionFinalized {
        // Expected.
    }
    do {
        _ = try await reopenedCompletedController.submit()
        throw CommandError.productValidationFailed("reopened completed controller accepted submit")
    } catch ProductDomainError.sessionFinalized {
        // Expected.
    }
    do {
        _ = try await flow.complete(reopenedCompletedController)
        throw CommandError.productValidationFailed("reopened completed controller accepted completion")
    } catch ProductDomainError.sessionFinalized {
        // Expected.
    }

    let earnedBlueprint = try await flow.blueprints.openBlueprint(
        artworkID: artworkID,
        entitlements: noEntitlement
    )
    guard earnedBlueprint.blueprint.blueprintID == "dev-blueprint-cardinality-2",
          earnedBlueprint.exportPlan.totalBeads == 2,
          earnedBlueprint.exportPlan.materialCounts == [
              BlueprintMaterialCount(colorId: "archive-blue", count: 2),
          ] else {
        throw CommandError.productValidationFailed("earned Blueprint or export plan is incorrect")
    }

    let replay = try await flow.reconcileStory()
    guard replay.count == 3,
          replay.allSatisfy({ decision in
              if case .alreadyApplied = decision { return true }
              return false
          }),
          try await flow.storyState().achievements.count == 1 else {
        throw CommandError.productValidationFailed("Story reconciliation is not stable and idempotent")
    }

    print([
        "✓ Integrated product flow validation",
        "  validated catalog: 1 Museum / 4 Artworks / 10 Fragments / 4 Blueprints",
        "  content-driven session: mutation autosave → flush → reopen → exact completion",
        "  atomic Artwork completion: receipt and state 0/2 → 1/2 → 2/2",
        "  completed sessions: immutable across live, pre-completion, and reopened controllers",
        "  entitlement-only Blueprint access: isolated from progress, seal, and Story",
        "  earned Blueprint: authorized with deterministic 16×16 PNG plan",
        "  production content: RFC 8785 vectors + manifest-selected revision/rollback",
        "  malformed production facts: hash/RGB/board/material/symbol/export rejection",
        "  Story reconciliation: global, deterministic, stable, and idempotent",
        "  Story persistence: concurrent apply is atomic; mappings are capability-checked",
        "  Museum 1 Canon: 28 ordered evidence events → 7 milestones",
        "  out-of-order Canon evidence: rejected without mutation",
    ].joined(separator: "\n"))
}

private func solve(
    _ controller: PuzzleSessionController,
    updatedAt: Date = Date()
) async throws {
    let puzzle = controller.puzzle
    let edits = puzzle.solution.cells.enumerated().compactMap { offset, colorID -> CellEdit? in
        guard let colorID else { return nil }
        return CellEdit(
            coordinate: CellCoordinate(
                x: offset % puzzle.solution.width,
                y: offset / puzzle.solution.width
            ),
            state: .filled(colorId: colorID)
        )
    }
    _ = try await controller.apply(edits, updatedAt: updatedAt)
    guard await controller.currentSession().isComplete else {
        throw CommandError.productValidationFailed("fixture solution did not complete its session")
    }
}

private func validateMuseum1StoryRules() async throws {
    let rules = try Museum1StoryRules.make()
    let store = InMemoryStoryStateStore()
    let processor = StoryEventProcessor(store: store, rules: rules)

    let secondRule = rules.orderedEvidence[1]
    let premature = envelope(
        rule: secondRule,
        index: 1,
        rules: rules,
        occurredAt: Date(timeIntervalSince1970: 1)
    )
    let rejected = try await processor.submit(premature)
    guard case .rejected(let error, _) = rejected,
          case .evidenceOutOfSequence = error,
          try await processor.state().acceptedEvidence.isEmpty else {
        throw CommandError.productValidationFailed("out-of-order Canon evidence was not rejected")
    }

    for (index, rule) in rules.orderedEvidence.enumerated() {
        let event = envelope(
            rule: rule,
            index: index,
            rules: rules,
            occurredAt: Date(timeIntervalSince1970: Double(index + 10))
        )
        let decision = try await processor.submit(event)
        guard case .applied = decision else {
            throw CommandError.productValidationFailed(
                "Museum 1 evidence \(rule.evidenceID.rawValue) was not applied"
            )
        }
        if index == 0 {
            guard case .alreadyApplied = try await processor.submit(event) else {
                throw CommandError.productValidationFailed("duplicate Canon evidence was not idempotent")
            }
        }
    }

    let state = try await processor.state()
    guard state.acceptedEvidence.count == rules.orderedEvidence.count,
          state.achievedMilestones == Set(StoryMilestoneID.allCases),
          state.achievements.map(\.milestone) == StoryMilestoneID.allCases else {
        throw CommandError.productValidationFailed("Museum 1 milestone chain is incomplete or unordered")
    }
}

private func envelope(
    rule: StoryEvidenceRule,
    index: Int,
    rules: StoryRuleSet,
    occurredAt: Date
) -> StoryEvidenceEnvelope {
    StoryEvidenceEnvelope(
        occurrenceID: StoryEvidenceOccurrenceID(rawValue: "museum1-evidence-\(index)"),
        evidenceID: rule.evidenceID,
        source: StoryEvidenceSource(
            kind: rule.sourceKind,
            referenceID: rule.evidenceID.rawValue,
            sessionID: rule.sourceKind == .bridgeSession ? "museum1-session" : nil
        ),
        occurredAt: occurredAt,
        rulesRevision: rules.revision
    )
}


private func validateProductionContentDefenses(directoryURL: URL) throws {
    let assetDirectory = directoryURL
        .appendingPathComponent("artworks")
        .appendingPathComponent("cardinality-2")
    let beadData = try Data(contentsOf: assetDirectory.appendingPathComponent("bead-pattern.json"))
    let blueprintData = try Data(contentsOf: assetDirectory.appendingPathComponent("blueprint.json"))
    let source = try ProductionContentValidator.decodeAndValidateBeadPattern(data: beadData)

    let canonicalA = try JCSCanonicalizer.canonicalData(
        Data("{\"drop\":0,\"b\":2,\"a\":1}".utf8),
        removingTopLevelField: "drop"
    )
    let canonicalB = try JCSCanonicalizer.canonicalData(
        Data(" { \"a\" : 1, \"drop\" : 9, \"b\" : 2 } ".utf8),
        removingTopLevelField: "drop"
    )
    guard canonicalA == canonicalB,
          String(data: canonicalA, encoding: .utf8) == "{\"a\":1,\"b\":2}" else {
        throw CommandError.productValidationFailed("JCS key ordering or whitespace canonicalization drifted")
    }
    let numericVector = try JCSCanonicalizer.canonicalData(
        Data("{\"drop\":0,\"numbers\":[333333333.33333329,1E30,4.50,2e-3,0.000000000000000000000000001,1e-7,0.000001]}".utf8),
        removingTopLevelField: "drop"
    )
    let numericText = String(data: numericVector, encoding: .utf8) ?? "<non-UTF8>"
    guard numericText
        == "{\"numbers\":[333333333.3333333,1e+30,4.5,0.002,1e-27,1e-7,0.000001]}" else {
        throw CommandError.productValidationFailed(
            "JCS ECMAScript number serialization drifted: \(numericText)"
        )
    }
    do {
        _ = try JCSCanonicalizer.canonicalData(
            Data("{\"drop\":0,\"duplicate\":1,\"duplicate\":2}".utf8),
            removingTopLevelField: "drop"
        )
        throw CommandError.productValidationFailed("JCS accepted duplicate object member names")
    } catch JCSCanonicalizationError.unsupportedValue {
        // Expected for non-I-JSON duplicate names.
    }
    let unicodeIdentityVector = try JCSCanonicalizer.canonicalData(
        Data("{\"drop\":0,\"é\":1,\"e\u{0301}\":2}".utf8),
        removingTopLevelField: "drop"
    )
    guard String(data: unicodeIdentityVector, encoding: .utf8)
        == "{\"e\u{0301}\":2,\"é\":1}" else {
        throw CommandError.productValidationFailed(
            "JCS normalized code-point-distinct Unicode member names"
        )
    }

    var changedDocument = try jsonObject(beadData)
    changedDocument["title"] = "Changed after hashing"
    do {
        _ = try ProductionContentValidator.decodeAndValidateBeadPattern(
            data: try JSONSerialization.data(withJSONObject: changedDocument)
        )
        throw CommandError.productValidationFailed("raw-document mutation preserved a production hash")
    } catch ProductionContentValidationError.hashMismatch {
        // Expected.
    }

    var invalidRGB = try jsonObject(beadData)
    var rgbPalette = invalidRGB["palette"] as! [[String: Any]]
    var rgbEntry = rgbPalette[0]
    var rgb = rgbEntry["sRGB8"] as! [String: Any]
    rgb["r"] = 256
    rgbEntry["sRGB8"] = rgb
    rgbPalette[0] = rgbEntry
    invalidRGB["palette"] = rgbPalette
    let invalidRGBPattern = try JSONDecoder().decode(
        BeadPatternDefinition.self,
        from: JSONSerialization.data(withJSONObject: invalidRGB)
    )
    try expectInvalidProductionField("out-of-range RGB") {
        try ProductionContentValidator.validate(beadPattern: invalidRGBPattern)
    }

    var invalidSymbol = try jsonObject(beadData)
    var symbolPalette = invalidSymbol["palette"] as! [[String: Any]]
    var symbolEntry = symbolPalette[0]
    symbolEntry["accessibilitySymbol"] = "AB"
    symbolPalette[0] = symbolEntry
    invalidSymbol["palette"] = symbolPalette
    let invalidSymbolPattern = try JSONDecoder().decode(
        BeadPatternDefinition.self,
        from: JSONSerialization.data(withJSONObject: invalidSymbol)
    )
    try expectInvalidProductionField("multi-grapheme accessibility symbol") {
        try ProductionContentValidator.validate(beadPattern: invalidSymbolPattern)
    }

    var lowResolutionExport = try jsonObject(blueprintData)
    var exportRules = lowResolutionExport["exportRules"] as! [String: Any]
    exportRules["pixelsPerCell"] = 7
    lowResolutionExport["exportRules"] = exportRules
    let lowResolutionBlueprint = try JSONDecoder().decode(
        BlueprintDefinition.self,
        from: JSONSerialization.data(withJSONObject: lowResolutionExport)
    )
    try expectInvalidProductionField("illegible Blueprint symbol resolution") {
        try ProductionContentValidator.validate(blueprint: lowResolutionBlueprint, source: source)
    }

    var invalidBoard = try jsonObject(beadData)
    var physical = invalidBoard["physical"] as! [String: Any]
    var board = physical["boardLayout"] as! [String: Any]
    board["columns"] = 2
    physical["boardLayout"] = board
    invalidBoard["physical"] = physical
    let invalidBoardPattern = try JSONDecoder().decode(
        BeadPatternDefinition.self,
        from: JSONSerialization.data(withJSONObject: invalidBoard)
    )
    try expectInvalidProductionField("board/grid mismatch") {
        try ProductionContentValidator.validate(beadPattern: invalidBoardPattern)
    }

    var duplicateMaterials = try jsonObject(blueprintData)
    var materials = duplicateMaterials["materialCounts"] as! [[String: Any]]
    materials.append(materials[0])
    duplicateMaterials["materialCounts"] = materials
    let duplicateBlueprint = try JSONDecoder().decode(
        BlueprintDefinition.self,
        from: JSONSerialization.data(withJSONObject: duplicateMaterials)
    )
    do {
        try ProductionContentValidator.validate(blueprint: duplicateBlueprint, source: source)
        throw CommandError.productValidationFailed("duplicate Blueprint materials were accepted")
    } catch ProductionContentValidationError.materialMismatch {
        // Expected; importantly this throws instead of trapping in Dictionary construction.
    }

    try validateActiveProductionRevisionSelection(directoryURL: directoryURL)
}

private func jsonObject(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw CommandError.productValidationFailed("fixture is not a JSON object")
    }
    return object
}

private func expectInvalidProductionField(
    _ description: String,
    operation: () throws -> Void
) throws {
    do {
        try operation()
        throw CommandError.productValidationFailed("\(description) was accepted")
    } catch ProductionContentValidationError.invalidField {
        // Expected.
    }
}

private func validateAtomicStoryStore() async throws {
    let evidenceID = StoryEvidenceID(rawValue: "atomic-story-evidence")
    let rules = try StoryRuleSet(
        id: "atomic-story-store-v1",
        revision: 1,
        orderedEvidence: [
            StoryEvidenceRule(evidenceID: evidenceID, sourceKind: .narrativeAction),
        ]
    )
    let store = InMemoryStoryStateStore()
    let firstProcessor = StoryEventProcessor(store: store, rules: rules)
    let secondProcessor = StoryEventProcessor(store: store, rules: rules)
    let firstEnvelope = StoryEvidenceEnvelope(
        occurrenceID: StoryEvidenceOccurrenceID(rawValue: "atomic-first"),
        evidenceID: evidenceID,
        source: StoryEvidenceSource(kind: .narrativeAction, referenceID: "first"),
        occurredAt: Date(timeIntervalSince1970: 1),
        rulesRevision: rules.revision
    )
    let secondEnvelope = StoryEvidenceEnvelope(
        occurrenceID: StoryEvidenceOccurrenceID(rawValue: "atomic-second"),
        evidenceID: evidenceID,
        source: StoryEvidenceSource(kind: .narrativeAction, referenceID: "second"),
        occurredAt: Date(timeIntervalSince1970: 2),
        rulesRevision: rules.revision
    )

    async let firstDecision = firstProcessor.submit(firstEnvelope)
    async let secondDecision = secondProcessor.submit(secondEnvelope)
    let decisions = try await [firstDecision, secondDecision]
    let appliedCount = decisions.filter { decision in
        if case .applied = decision { return true }
        return false
    }.count
    let finalState = try await firstProcessor.state()
    guard appliedCount == 1, finalState.acceptedEvidence.count == 1 else {
        throw CommandError.productValidationFailed("atomic Story apply admitted or lost concurrent evidence")
    }
}

private func validateStoryMappingDefenses(catalog: RuntimeContentCatalog) throws {
    let fragmentEvidence = StoryEvidenceID(rawValue: "mapping.fragment")
    let artworkEvidence = StoryEvidenceID(rawValue: "mapping.artwork")
    let rules = try StoryRuleSet(
        id: "mapping-validation-v1",
        revision: 1,
        orderedEvidence: [
            StoryEvidenceRule(evidenceID: fragmentEvidence, sourceKind: .fragmentCompletion),
            StoryEvidenceRule(evidenceID: artworkEvidence, sourceKind: .artworkRestoration),
        ]
    )

    try expectInvalidStoryMapping {
        _ = try ProductFlow(
            catalog: catalog,
            progressStore: InMemoryProgressStore(),
            storyProcessor: StoryEventProcessor(store: InMemoryStoryStateStore(), rules: rules),
            storyMapping: CompletionStoryMapping(fragmentEvidence: ["missing-fragment": fragmentEvidence])
        )
    }
    try expectInvalidStoryMapping {
        _ = try ProductFlow(
            catalog: catalog,
            progressStore: InMemoryProgressStore(),
            storyProcessor: StoryEventProcessor(store: InMemoryStoryStateStore(), rules: rules),
            storyMapping: CompletionStoryMapping(fragmentEvidence: ["dev-a2-f01": artworkEvidence])
        )
    }
    try expectInvalidStoryMapping {
        _ = try ProductFlow(
            catalog: catalog,
            progressStore: InMemoryProgressStore(),
            storyProcessor: StoryEventProcessor(store: InMemoryStoryStateStore(), rules: rules),
            storyMapping: CompletionStoryMapping(fragmentEvidence: [
                "dev-a2-f01": fragmentEvidence,
                "dev-a2-f02": fragmentEvidence,
            ])
        )
    }
}

private func expectInvalidStoryMapping(_ operation: () throws -> Void) throws {
    do {
        try operation()
        throw CommandError.productValidationFailed("invalid Story mapping was accepted")
    } catch ProductDomainError.invalidStoryMapping {
        // Expected.
    }
}


private func validateActiveProductionRevisionSelection(directoryURL: URL) throws {
    let manager = FileManager.default
    let temporaryRoot = manager.temporaryDirectory
        .appendingPathComponent("kanaka-production-revisions-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: temporaryRoot) }
    try manager.copyItem(at: directoryURL, to: temporaryRoot)

    let originalDirectory = temporaryRoot
        .appendingPathComponent("artworks")
        .appendingPathComponent("cardinality-2")
    let revisionDirectory = temporaryRoot
        .appendingPathComponent("revision-history")
        .appendingPathComponent("cardinality-2-r2")
    try manager.createDirectory(at: revisionDirectory, withIntermediateDirectories: true)

    var bead = try jsonObject(Data(contentsOf: originalDirectory.appendingPathComponent("bead-pattern.json")))
    bead["revision"] = 2
    bead["title"] = "Fixture Artwork 2 revision 2"
    let beadHash = try rehash(&bead, field: "contentHash")
    try JSONSerialization.data(withJSONObject: bead, options: [.prettyPrinted, .sortedKeys])
        .write(to: revisionDirectory.appendingPathComponent("bead-pattern.json"))

    var blueprint = try jsonObject(Data(contentsOf: originalDirectory.appendingPathComponent("blueprint.json")))
    blueprint["revision"] = 2
    var source = blueprint["sourceBeadAsset"] as! [String: Any]
    source["revision"] = 2
    source["contentHash"] = beadHash
    blueprint["sourceBeadAsset"] = source
    let blueprintHash = try rehash(&blueprint, field: "blueprintHash")
    try JSONSerialization.data(withJSONObject: blueprint, options: [.prettyPrinted, .sortedKeys])
        .write(to: revisionDirectory.appendingPathComponent("blueprint.json"))

    let manifestURL = temporaryRoot.appendingPathComponent("production-assets.json")
    var manifest = try jsonObject(Data(contentsOf: manifestURL))
    var activeBeads = manifest["activeBeadAssets"] as! [[String: Any]]
    let beadIndex = activeBeads.firstIndex { $0["assetId"] as? String == "dev-bead-cardinality-2" }!
    activeBeads[beadIndex]["revision"] = 2
    activeBeads[beadIndex]["contentHash"] = beadHash
    manifest["activeBeadAssets"] = activeBeads
    var activeBlueprints = manifest["activeBlueprints"] as! [[String: Any]]
    let blueprintIndex = activeBlueprints.firstIndex {
        $0["blueprintId"] as? String == "dev-blueprint-cardinality-2"
    }!
    activeBlueprints[blueprintIndex]["revision"] = 2
    activeBlueprints[blueprintIndex]["blueprintHash"] = blueprintHash
    manifest["activeBlueprints"] = activeBlueprints
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: manifestURL, options: .atomic)

    let upgraded = try RuntimeContentCatalog.loadValidated(directoryURL: temporaryRoot)
    guard upgraded.activeProductionRevisions.beadPatterns["dev-bead-cardinality-2"] == 2,
          upgraded.activeProductionRevisions.blueprints["dev-blueprint-cardinality-2"] == 2,
          upgraded.productionAssetCounts.beadPatterns == 4,
          upgraded.productionAssetCounts.blueprints == 4 else {
        throw CommandError.productValidationFailed("manifest did not activate exact production revision 2")
    }

    activeBeads[beadIndex]["revision"] = 1
    activeBeads[beadIndex]["contentHash"] = "sha256:eb93b045dc2a8e1568369a3953c0f7492bb019f9a778a3495cf5d1b123ce3499"
    manifest["activeBeadAssets"] = activeBeads
    activeBlueprints[blueprintIndex]["revision"] = 1
    activeBlueprints[blueprintIndex]["blueprintHash"] = "sha256:32966d53b74541f1e846de3a1f58ca5e13bc4b371633508c02fa291ff7e939ad"
    manifest["activeBlueprints"] = activeBlueprints
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: manifestURL, options: .atomic)

    let rolledBack = try RuntimeContentCatalog.loadValidated(directoryURL: temporaryRoot)
    guard rolledBack.activeProductionRevisions.beadPatterns["dev-bead-cardinality-2"] == 1,
          rolledBack.activeProductionRevisions.blueprints["dev-blueprint-cardinality-2"] == 1 else {
        throw CommandError.productValidationFailed("manifest rollback did not select exact revision 1")
    }
}

@discardableResult
private func rehash(_ object: inout [String: Any], field: String) throws -> String {
    object[field] = "sha256:" + String(repeating: "0", count: 64)
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let canonical = try JCSCanonicalizer.canonicalData(data, removingTopLevelField: field)
    let hash = "sha256:" + SHA256.hexDigest(canonical)
    object[field] = hash
    return hash
}
