import Foundation
import KanakaContentKit
import KanakaCore
import KanakaProductDomain
import KanakaProgress
import KanakaStory

private enum ExpectedRestorationStatus {
    case notStarted
    case inProgress
    case completed
}

/// Linux-first v0.4 acceptance gate for the synthetic three-Fragment App catalog.
func validateRestorationPack(directoryURL: URL) async throws {
    let catalog = try RuntimeContentCatalog.loadValidated(directoryURL: directoryURL)
    let expectedMuseumID = "dev-museum-restoration-pack"
    let expectedGalleryID = "dev-gallery-restoration-pack"
    let expectedArtworkID = "dev-artwork-restoration-pack"
    let expectedFragmentIDs = [
        "dev-restoration-f01",
        "dev-restoration-f02",
        "dev-restoration-f03",
    ]
    let expectedPuzzleDimensions = [(5, 5), (10, 10), (15, 15)]

    guard catalog.museums.count == 1,
          catalog.galleries.count == 1,
          catalog.artworks.count == 1,
          catalog.fragments.count == 3,
          catalog.puzzles.count == 3,
          catalog.productionAssetCounts.beadPatterns == 1,
          catalog.productionAssetCounts.blueprints == 1,
          let museum = catalog.museums[expectedMuseumID],
          let gallery = catalog.galleries[expectedGalleryID],
          let artwork = catalog.artworks[expectedArtworkID],
          museum.galleryIDs == [expectedGalleryID],
          gallery.museumID == expectedMuseumID,
          gallery.artworkIDs == [expectedArtworkID],
          artwork.repairFragmentIDs == expectedFragmentIDs,
          artwork.blueprintID == "dev-blueprint-restoration-pack" else {
        throw restorationFailure(
            "expected the exact one-Museum/one-Gallery/one-Artwork three-Fragment development hierarchy"
        )
    }

    let orderedContexts = try expectedFragmentIDs.map { try catalog.fragmentContext(id: $0) }
    for (index, context) in orderedContexts.enumerated() {
        let expectedDimensions = expectedPuzzleDimensions[index]
        guard context.fragment.artworkID == expectedArtworkID,
              context.puzzle.id == "dev-restoration-f0\(index + 1)-p01",
              context.puzzle.solution.width == expectedDimensions.0,
              context.puzzle.solution.height == expectedDimensions.1,
              context.puzzle.kind == .formal,
              context.puzzle.prefilledCells.isEmpty,
              context.fragment.id.hasPrefix("dev-"),
              context.puzzle.id.hasPrefix("dev-") else {
            throw restorationFailure("Fragment \(index + 1) identity or puzzle contract is incorrect")
        }
    }
    try validatePartition(orderedContexts.map(\.fragment.region))

    guard catalog.experience.revision == 2,
          catalog.experience.tutorial.puzzleID == orderedContexts[0].puzzle.id,
          catalog.experience.museums.map(\.id) == [expectedMuseumID],
          catalog.experience.galleries.map(\.id) == [expectedGalleryID],
          catalog.experience.artworks.map(\.id) == [expectedArtworkID],
          catalog.experience.fragments.map(\.id) == expectedFragmentIDs else {
        throw restorationFailure("playable presentation does not exactly cover the v0.4 hierarchy")
    }

    let progressStore = InMemoryProgressStore()
    let storyStore = InMemoryStoryStateStore()
    let storyRules = try Museum1StoryRules.make()
    func makeFlow() throws -> ProductFlow {
        try ProductFlow(
            catalog: catalog,
            progressStore: progressStore,
            storyProcessor: StoryEventProcessor(store: storyStore, rules: storyRules),
            storyMapping: CompletionStoryMapping(),
            throttleDelay: .seconds(60)
        )
    }

    let initialFlow = try makeFlow()
    let noEntitlements = MuseumEntitlementSnapshot()
    let initial = try await initialFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: noEntitlements
    )
    try requireRestoration(
        initial.artworkState.completedCount == 0
            && initial.artworkState.totalCount == 3
            && !initial.artworkState.access.artworkRestored
            && !initial.artworkState.access.canUseArtworkBlueprint
            && !initial.artworkState.access.hasRestorerSeal,
        "initial Artwork state is not a locked 0/3"
    )
    try requireStatuses(initial, expected: Dictionary(
        uniqueKeysWithValues: expectedFragmentIDs.map { ($0, ExpectedRestorationStatus.notStarted) }
    ))

    // Matching entitlement grants Blueprint-only access; it must not restore, seal, save, or tell Story.
    let matchingEntitlement = MuseumEntitlementSnapshot(museumIDs: [expectedMuseumID])
    let entitled = try await initialFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: matchingEntitlement
    )
    try requireRestoration(
        entitled.artworkState.completedCount == 0
            && !entitled.artworkState.access.artworkRestored
            && entitled.artworkState.access.canUseArtworkBlueprint
            && !entitled.artworkState.access.hasRestorerSeal,
        "matching entitlement changed progress/seal or failed Blueprint-only access"
    )
    try requireStatuses(entitled, expected: Dictionary(
        uniqueKeysWithValues: expectedFragmentIDs.map { ($0, ExpectedRestorationStatus.notStarted) }
    ))
    let entitledBlueprint = try await initialFlow.blueprints.openBlueprint(
        artworkID: expectedArtworkID,
        entitlements: matchingEntitlement
    )
    try requireRestoration(
        entitledBlueprint.blueprint.blueprintID == "dev-blueprint-restoration-pack",
        "matching entitlement opened the wrong Blueprint"
    )

    let unrelatedEntitlement = MuseumEntitlementSnapshot(museumIDs: ["dev-unrelated-museum"])
    let unrelated = try await initialFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: unrelatedEntitlement
    )
    try requireRestoration(
        unrelated.artworkState.completedCount == 0
            && !unrelated.artworkState.access.artworkRestored
            && !unrelated.artworkState.access.canUseArtworkBlueprint
            && !unrelated.artworkState.access.hasRestorerSeal,
        "unrelated entitlement changed Artwork access"
    )
    do {
        _ = try await initialFlow.blueprints.openBlueprint(
            artworkID: expectedArtworkID,
            entitlements: unrelatedEntitlement
        )
        throw restorationFailure("unrelated entitlement opened the Blueprint")
    } catch ProductDomainError.blueprintAccessDenied {
        // Expected: only the matching Museum entitlement grants Blueprint-only access.
    }
    let entitlementStoryState = try await initialFlow.storyState()
    try requireRestoration(
        entitlementStoryState.acceptedEvidence.isEmpty,
        "entitlement access advanced Story"
    )

    // Opening and closing without mutation is intentionally side-effect free.
    let untouched = try await initialFlow.openFragment(expectedFragmentIDs[0])
    try await untouched.flush()
    let afterUntouchedOpen = try await initialFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: noEntitlements
    )
    try requireStatuses(afterUntouchedOpen, expected: Dictionary(
        uniqueKeysWithValues: expectedFragmentIDs.map { ($0, ExpectedRestorationStatus.notStarted) }
    ))

    // One durable but incomplete edit creates the exact-current in-progress state.
    let firstPuzzle = orderedContexts[0].puzzle
    guard let partialEdit = solutionEditsForRestorationPack(firstPuzzle).first else {
        throw restorationFailure("5×5 puzzle has no colored cell for resume validation")
    }
    let partialController = try await initialFlow.openFragment(expectedFragmentIDs[0])
    _ = try await partialController.apply([partialEdit])
    try await partialController.flush()
    let partial = try await initialFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: noEntitlements
    )
    try requireStatuses(partial, expected: [
        expectedFragmentIDs[0]: .inProgress,
        expectedFragmentIDs[1]: .notStarted,
        expectedFragmentIDs[2]: .notStarted,
    ])

    // A fresh ProductFlow over the same store must restore the exact cell and generation.
    let resumedFlow = try makeFlow()
    let resumedFirst = try await resumedFlow.openFragment(expectedFragmentIDs[0])
    let resumedSession = await resumedFirst.currentSession()
    try requireRestoration(
        try resumedSession.cell(at: partialEdit.coordinate) == partialEdit.state,
        "flushed in-progress cell did not survive reopen"
    )

    // Complete out of configured order to prove count/state derivation never assumes sequence.
    let firstOutcome = try await completeRestorationFragment(
        expectedFragmentIDs[1],
        flow: resumedFlow,
        completedAt: Date(timeIntervalSince1970: 4_000)
    )
    try requireRestoration(
        firstOutcome.artworkState.completedCount == 1
            && firstOutcome.artworkState.totalCount == 3
            && !firstOutcome.artworkState.access.artworkRestored
            && !firstOutcome.artworkState.access.canUseArtworkBlueprint
            && !firstOutcome.artworkState.access.hasRestorerSeal,
        "first out-of-order completion did not produce a locked 1/3"
    )
    let oneOfThree = try await resumedFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: noEntitlements
    )
    try requireStatuses(oneOfThree, expected: [
        expectedFragmentIDs[0]: .inProgress,
        expectedFragmentIDs[1]: .completed,
        expectedFragmentIDs[2]: .notStarted,
    ])

    _ = try await resumedFirst.apply(solutionEditsForRestorationPack(firstPuzzle))
    let secondOutcome = try await resumedFlow.complete(
        resumedFirst,
        entitlements: noEntitlements,
        completedAt: Date(timeIntervalSince1970: 5_000)
    )
    try requireRestoration(
        secondOutcome.artworkState.completedCount == 2
            && !secondOutcome.artworkState.access.artworkRestored
            && !secondOutcome.artworkState.access.canUseArtworkBlueprint
            && !secondOutcome.artworkState.access.hasRestorerSeal,
        "second completion did not produce a locked 2/3"
    )

    let finalOutcome = try await completeRestorationFragment(
        expectedFragmentIDs[2],
        flow: resumedFlow,
        completedAt: Date(timeIntervalSince1970: 6_000)
    )
    try requireRestoration(
        finalOutcome.artworkState.completedCount == 3
            && finalOutcome.artworkState.access.artworkRestored
            && finalOutcome.artworkState.access.canUseArtworkBlueprint
            && finalOutcome.artworkState.access.hasRestorerSeal,
        "final completion did not restore Artwork and award Blueprint/seal"
    )

    let finalSnapshot = try await resumedFlow.artworkStates.restorationSnapshot(
        artworkID: expectedArtworkID,
        entitlements: noEntitlements
    )
    try requireStatuses(finalSnapshot, expected: Dictionary(
        uniqueKeysWithValues: expectedFragmentIDs.map { ($0, ExpectedRestorationStatus.completed) }
    ))

    let reopenedCompleted = try await resumedFlow.openFragment(expectedFragmentIDs[1])
    let reopenedIsFinalized = await reopenedCompleted.isFinalized()
    let reopenedSession = await reopenedCompleted.currentSession()
    try requireRestoration(
        reopenedIsFinalized && reopenedSession.isComplete,
        "completed Fragment did not reopen as a finalized complete session"
    )

    let authorized = try await resumedFlow.blueprints.openBlueprint(
        artworkID: expectedArtworkID,
        entitlements: noEntitlements
    )
    try requireRestoration(
        authorized.blueprint.blueprintID == "dev-blueprint-restoration-pack"
            && authorized.blueprint.grid.width == 15
            && authorized.blueprint.grid.height == 15
            && authorized.exportPlan.pixelWidth == 240
            && authorized.exportPlan.pixelHeight == 240
            && authorized.exportPlan.totalBeads == 128,
        "earned final Blueprint/export plan is incorrect"
    )
    let finalStoryState = try await resumedFlow.storyState()
    try requireRestoration(
        finalStoryState.acceptedEvidence.isEmpty,
        "synthetic restoration pack advanced Story"
    )

    print([
        "✓ Realistic restoration pack validation",
        "  catalog: 1 Museum / 1 Gallery / 1 Artwork / 3 Fragments",
        "  formal puzzles: 5×5 → 10×10 → 15×15, unique pure-logic validated",
        "  tri-state progress: not started → in progress → completed",
        "  entitlement isolation: matching Blueprint-only; unrelated denied; Progress/Story unchanged",
        "  side-effect-free open: passed; flush/reopen resume: passed",
        "  staged completion: 0/3 → 1/3 → 2/3 → 3/3 out of configured order",
        "  final unlocks: 15×15 Blueprint + restorer seal",
        "  development Story mapping: intentionally empty",
    ].joined(separator: "\n"))
}

private func completeRestorationFragment(
    _ fragmentID: String,
    flow: ProductFlow,
    completedAt: Date
) async throws -> FragmentCompletionOutcome {
    let controller = try await flow.openFragment(fragmentID)
    _ = try await controller.apply(solutionEditsForRestorationPack(controller.puzzle))
    let completedSession = await controller.currentSession()
    try requireRestoration(
        completedSession.isComplete,
        "solution batch did not complete \(fragmentID)"
    )
    return try await flow.complete(
        controller,
        entitlements: MuseumEntitlementSnapshot(),
        completedAt: completedAt
    )
}

private func solutionEditsForRestorationPack(_ puzzle: PuzzleDefinition) -> [CellEdit] {
    puzzle.solution.cells.enumerated().compactMap { offset, colorID in
        guard let colorID else { return nil }
        return CellEdit(
            coordinate: CellCoordinate(
                x: offset % puzzle.solution.width,
                y: offset / puzzle.solution.width
            ),
            state: .filled(colorId: colorID)
        )
    }
}

private func validatePartition(_ regions: [NormalizedRegion]) throws {
    guard regions.count == 3 else { throw restorationFailure("expected three restoration regions") }
    let tolerance = 0.000_001
    guard regions.allSatisfy({
        abs($0.y) <= tolerance && abs($0.height - 1) <= tolerance
    }),
    abs(regions[0].x) <= tolerance,
    abs((regions[0].x + regions[0].width) - regions[1].x) <= tolerance,
    abs((regions[1].x + regions[1].width) - regions[2].x) <= tolerance,
    abs((regions[2].x + regions[2].width) - 1) <= tolerance else {
        throw restorationFailure("Fragment regions do not form a full non-overlapping partition")
    }
}

private func requireStatuses(
    _ snapshot: ArtworkRestorationSnapshot,
    expected: [String: ExpectedRestorationStatus]
) throws {
    guard snapshot.fragments.count == expected.count else {
        throw restorationFailure("restoration status count is incorrect")
    }
    for fragment in snapshot.fragments {
        guard let expectedStatus = expected[fragment.fragmentID] else {
            throw restorationFailure("unexpected Fragment status \(fragment.fragmentID)")
        }
        let matches: Bool
        switch (fragment.status, expectedStatus) {
        case (.notStarted, .notStarted), (.inProgress, .inProgress), (.completed, .completed):
            matches = true
        default:
            matches = false
        }
        guard matches else {
            throw restorationFailure("Fragment \(fragment.fragmentID) status is incorrect")
        }
    }
}

private func requireRestoration(_ condition: @autoclosure () throws -> Bool, _ reason: String) throws {
    guard try condition() else { throw restorationFailure(reason) }
}

private func restorationFailure(_ reason: String) -> CommandError {
    .restorationPackValidationFailed(reason)
}
