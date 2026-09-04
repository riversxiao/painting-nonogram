import Foundation
import KanakaContentKit
import KanakaCore
import KanakaProductDomain
import KanakaProgress
import KanakaStory

func validatePlayableExperience(directoryURL: URL) async throws {
    let catalog = try RuntimeContentCatalog.loadValidated(directoryURL: directoryURL)
    let experience = catalog.experience

    let localizedValues = experience.introPages.flatMap { [$0.title, $0.body] }
        + [
            experience.tutorial.title,
            experience.tutorial.body,
            experience.tutorial.skipLabel,
            experience.tutorial.completeLabel,
        ]
        + experience.routes.flatMap { [$0.title, $0.subtitle, $0.body, $0.actionLabel] }
        + (experience.museums + experience.galleries + experience.artworks + experience.fragments)
            .flatMap { presentation in
                [
                    presentation.title,
                    presentation.subtitle,
                    presentation.body,
                    presentation.completionTitle,
                    presentation.completionBody,
                ].compactMap { $0 }
            }
    guard localizedValues.allSatisfy({ value in
        !value.resolved(preferredLocales: ["zh-Hans"], defaultLocale: experience.defaultLocale).isEmpty
            && !value.resolved(preferredLocales: ["en"], defaultLocale: experience.defaultLocale).isEmpty
    }) else {
        throw CommandError.experienceValidationFailed("localized presentation did not resolve")
    }

    guard Set(experience.routes.map(\.route)) == Set(PlayableExperienceRoute.allCases),
          let tutorialPuzzle = catalog.puzzles[experience.tutorial.puzzleID] else {
        throw CommandError.experienceValidationFailed("routes or tutorial Puzzle are missing")
    }

    let progressStore = InMemoryProgressStore()
    let storyStore = InMemoryStoryStateStore()
    let storyRules = try Museum1StoryRules.make()
    let productFlow = try ProductFlow(
        catalog: catalog,
        progressStore: progressStore,
        storyProcessor: StoryEventProcessor(store: storyStore, rules: storyRules),
        storyMapping: CompletionStoryMapping(),
        throttleDelay: .seconds(60)
    )

    var tutorialSession = try GameSession(puzzle: tutorialPuzzle)
    _ = try tutorialSession.applyBatch(solutionEdits(for: tutorialPuzzle))
    guard tutorialSession.isComplete else {
        throw CommandError.experienceValidationFailed("ephemeral tutorial did not complete")
    }
    guard let tutorialFragment = catalog.fragments.values.first(where: {
        $0.puzzleDefinitionID == tutorialPuzzle.id
    }),
          try await progressStore.records(for: tutorialFragment.id).isEmpty,
          try await productFlow.storyState().acceptedEvidence.isEmpty else {
        throw CommandError.experienceValidationFailed(
            "ephemeral tutorial changed Fragment progress or Story"
        )
    }

    var completedPath = try PlayableExperienceFlow()
    try completedPath.acknowledgeWorldIntro()
    try completedPath.completeTutorial()
    try completedPath.chooseInitialRoute(.restoration)
    guard completedPath.state.phase == .ready(.restoration),
          completedPath.state.tutorialDisposition == .completed else {
        throw CommandError.experienceValidationFailed("completed tutorial path did not become ready")
    }
    let stateStore = InMemoryPlayableExperienceStateStore()
    try await stateStore.save(completedPath.state)
    guard try await stateStore.load() == completedPath.state else {
        throw CommandError.experienceValidationFailed("experience state did not round trip")
    }

    var skippedPath = try PlayableExperienceFlow()
    try skippedPath.acknowledgeWorldIntro()
    try skippedPath.skipTutorial()
    try skippedPath.chooseInitialRoute(.workshop)
    guard skippedPath.state.phase == .ready(.workshop),
          skippedPath.state.tutorialDisposition == .skipped else {
        throw CommandError.experienceValidationFailed("skipped tutorial path did not become ready")
    }
    do {
        try skippedPath.completeTutorial()
        throw CommandError.experienceValidationFailed("invalid onboarding transition was accepted")
    } catch PlayableExperienceFlowError.invalidTransition {
        // Expected: onboarding state is monotonic until an explicit reset.
    }

    let contradictoryState = PlayableExperienceState(
        hasAcknowledgedWorldIntro: true,
        tutorialDisposition: nil,
        initialRoute: .workshop
    )
    do {
        _ = try PlayableExperienceFlow(state: contradictoryState)
        throw CommandError.experienceValidationFailed(
            "contradictory persisted onboarding state was accepted"
        )
    } catch PlayableExperienceFlowError.invalidState {
        // Expected: persisted fields may not preselect a route before tutorial disposition.
    }

    guard let multiFragmentArtwork = catalog.artworks.values
        .filter({ $0.repairFragmentIDs.count >= 2 })
        .sorted(by: { lhs, rhs in
            if lhs.repairFragmentIDs.count != rhs.repairFragmentIDs.count {
                return lhs.repairFragmentIDs.count < rhs.repairFragmentIDs.count
            }
            return lhs.id < rhs.id
        })
        .first else {
        throw CommandError.experienceValidationFailed("no multi-Fragment development Artwork found")
    }

    var feedback: [CompletionFeedback] = []
    for fragmentID in multiFragmentArtwork.repairFragmentIDs {
        let controller = try await productFlow.openFragment(fragmentID)
        _ = try await controller.apply(solutionEdits(for: controller.puzzle))
        guard await controller.currentSession().isComplete else {
            throw CommandError.experienceValidationFailed("development Fragment did not solve")
        }
        feedback.append(CompletionFeedback(outcome: try await productFlow.complete(controller)))
    }

    let expectedCount = multiFragmentArtwork.repairFragmentIDs.count
    let intermediate = feedback.dropLast()
    guard feedback.count == expectedCount,
          feedback.enumerated().allSatisfy({ index, item in
              item.completedCount == index + 1 && item.totalCount == expectedCount
          }),
          intermediate.allSatisfy({
              !$0.isArtworkRestored && !$0.blueprintAvailable && !$0.restorerSealAwarded
          }),
          let final = feedback.last,
          final.completedCount == expectedCount,
          final.isArtworkRestored,
          final.blueprintAvailable,
          final.restorerSealAwarded,
          feedback.allSatisfy({ $0.newlyAcceptedEvidenceIDs.isEmpty }),
          try await productFlow.storyState().acceptedEvidence.isEmpty else {
        throw CommandError.experienceValidationFailed(
            "intermediate/final completion feedback or Story isolation is incorrect"
        )
    }

    print([
        "✓ Playable experience validation",
        "  presentation: exact hierarchy coverage with zh-Hans/en fallback",
        "  onboarding: intro → completed/skipped tutorial → either initial route",
        "  tutorial: isolated 5×5 GameSession; no Progress or Story mutation",
        "  state persistence: versioned round trip; contradictory payload rejected",
        "  multi-Fragment Artwork: intermediate 1/\(expectedCount) → final \(expectedCount)/\(expectedCount) feedback",
        "  final unlocks: Artwork + Blueprint + restorer seal",
        "  development Story mapping: intentionally empty",
    ].joined(separator: "\n"))
}

private func solutionEdits(for puzzle: PuzzleDefinition) -> [CellEdit] {
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
