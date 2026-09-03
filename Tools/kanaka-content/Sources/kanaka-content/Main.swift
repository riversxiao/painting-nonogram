import Foundation
import KanakaContentKit
import KanakaCore
import KanakaProgress
import KanakaProductDomain
import KanakaStory

@main
enum KanakaContentCommand {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard arguments.count == 2 else { throw CommandError.usage }

            switch arguments[0] {
            case "validate-puzzle":
                let puzzleURL = URL(fileURLWithPath: arguments[1])
                let report = try PuzzleContentValidator.validate(contentsOf: puzzleURL)
                print(report.formattedDescription)
            case "validate-puzzles":
                try validatePuzzles(in: URL(fileURLWithPath: arguments[1]))
            case "validate-content":
                let directoryURL = URL(fileURLWithPath: arguments[1])
                let report = try ContentBundleValidator.validate(directoryURL: directoryURL)
                let catalog = try RuntimeContentCatalog.loadValidated(directoryURL: directoryURL)
                print(report.formattedDescription)
                print("  bead patterns: \(catalog.productionAssetCounts.beadPatterns), blueprints: \(catalog.productionAssetCounts.blueprints)")
            case "validate-session":
                try validateSession(
                    puzzleURL: URL(fileURLWithPath: arguments[1])
                )
            case "validate-progress":
                try await validateProgress(
                    puzzleURL: URL(fileURLWithPath: arguments[1])
                )
            case "validate-access":
                try validateAccess(
                    artworkURL: URL(fileURLWithPath: arguments[1])
                )
            case "validate-product-flow":
                try await validateProductFlow(
                    directoryURL: URL(fileURLWithPath: arguments[1])
                )
            default:
                throw CommandError.usage
            }
        } catch {
            let message = "error: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }

    private static func validatePuzzles(in directoryURL: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CommandError.invalidDirectory(directoryURL.path)
        }
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CommandError.invalidDirectory(directoryURL.path)
        }

        var puzzleURLs: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "puzzle-definition.json" {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true { puzzleURLs.append(fileURL) }
        }
        puzzleURLs.sort { $0.path < $1.path }
        guard !puzzleURLs.isEmpty else {
            throw CommandError.noPuzzleDefinitions(directoryURL.path)
        }

        for (index, puzzleURL) in puzzleURLs.enumerated() {
            if index > 0 { print("") }
            print(try PuzzleContentValidator.validate(contentsOf: puzzleURL).formattedDescription)
        }
        print("\n✓ validated \(puzzleURLs.count) puzzle definition(s)")
    }

    private static func validateSession(puzzleURL: URL) throws {
        let puzzle = try JSONDecoder().decode(
            PuzzleDefinition.self,
            from: Data(contentsOf: puzzleURL)
        )
        _ = try PuzzleContentValidator.validate(puzzle)

        var session = try GameSession(puzzle: puzzle)
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
        let completionChange = try session.applyBatch(edits)
        guard completionChange.createdHistoryEntry,
              session.completionStatus == .completedWithoutHints,
              session.canUndo else {
            throw CommandError.sessionValidationFailed("solution batch did not complete without hints")
        }

        guard session.undo() != nil,
              session.completionStatus == .incomplete,
              session.canRedo else {
            throw CommandError.sessionValidationFailed("undo did not restore the incomplete state")
        }
        guard session.redo() != nil,
              session.completionStatus == .completedWithoutHints else {
            throw CommandError.sessionValidationFailed("redo did not restore completion")
        }

        let snapshot = try session.makeSnapshot()
        let restored = try GameSession.restore(puzzle: puzzle, from: snapshot)
        guard restored.cells == session.cells,
              restored.completionStatus == .completedWithoutHints,
              !restored.canUndo,
              !restored.canRedo else {
            throw CommandError.sessionValidationFailed("snapshot round trip changed session state")
        }

        let changedRevisionSnapshot = SavedSessionSnapshot(
            metadata: SavedSessionMetadata(
                codecVersion: snapshot.metadata.codecVersion,
                puzzleID: snapshot.metadata.puzzleID,
                puzzleRevision: snapshot.metadata.puzzleRevision + 1,
                puzzleSemanticHash: snapshot.metadata.puzzleSemanticHash,
                width: snapshot.metadata.width,
                height: snapshot.metadata.height,
                cellCount: snapshot.metadata.cellCount,
                paletteColorIDsByIndex: snapshot.metadata.paletteColorIDsByIndex
            ),
            encodedCells: snapshot.encodedCells,
            assistanceHistory: snapshot.assistanceHistory
        )
        let migrationDecision = SessionRestoreEvaluator.evaluate(
            snapshot: changedRevisionSnapshot,
            current: puzzle
        )
        guard case .requiresMigration(.revisionChangedSemanticHashUnchanged) = migrationDecision else {
            throw CommandError.sessionValidationFailed("revision mismatch was not routed to migration")
        }

        var assisted = restored
        _ = assisted.recordAssistance(.hint)
        guard assisted.completionStatus == .completed else {
            throw CommandError.sessionValidationFailed("assistance did not revoke no-hint eligibility")
        }

        print([
            "✓ GameSession smoke validation",
            "  puzzle: \(puzzle.id) revision \(puzzle.revision)",
            "  solution edits: \(edits.count) in one transaction",
            "  completion: completedWithoutHints",
            "  undo/redo: passed",
            "  UInt8 snapshot round trip: \(snapshot.encodedCells.count) cells",
            "  restored history: intentionally empty",
            "  revision mismatch migration gate: passed",
            "  assistance monotonicity: passed",
        ].joined(separator: "\n"))
    }

    private static func validateProgress(puzzleURL: URL) async throws {
        let puzzle = try JSONDecoder().decode(
            PuzzleDefinition.self,
            from: Data(contentsOf: puzzleURL)
        )
        _ = try PuzzleContentValidator.validate(puzzle)

        let store = InMemoryProgressStore()
        let firstFragmentID = "smoke-fragment-1"
        let secondFragmentID = "smoke-fragment-2"
        let firstKey = ProgressRecordKey(fragmentID: firstFragmentID, puzzle: puzzle)
        let secondKey = ProgressRecordKey(fragmentID: secondFragmentID, puzzle: puzzle)
        let requiredKeys = [firstKey, secondKey]

        let opened = try await ProgressSessionLoader.open(
            fragmentID: firstFragmentID,
            puzzle: puzzle,
            store: store
        )
        guard case .new(var firstSession, let initialGeneration) = opened,
              initialGeneration == 0 else {
            throw CommandError.progressValidationFailed("new Fragment did not open cleanly")
        }

        let firstCoordinator = try SessionAutosaveCoordinator(
            fragmentID: firstFragmentID,
            persistedGeneration: initialGeneration,
            store: store,
            throttleDelay: .seconds(60)
        )

        // Assistance-only state and a later cell edit are coalesced; explicit flush wins over the timer.
        _ = firstSession.recordAssistance(.hint)
        _ = try await firstCoordinator.submit(snapshot: firstSession.makeSnapshot())
        guard let firstColoredOffset = puzzle.solution.cells.firstIndex(where: { $0 != nil }),
              let firstColorID = puzzle.solution.cells[firstColoredOffset] else {
            throw CommandError.progressValidationFailed("fixture has no colored answer cell")
        }
        _ = try firstSession.applyBatch([
            CellEdit(
                coordinate: CellCoordinate(
                    x: firstColoredOffset % puzzle.solution.width,
                    y: firstColoredOffset / puzzle.solution.width
                ),
                state: .filled(colorId: firstColorID)
            ),
        ])
        _ = try await firstCoordinator.submit(snapshot: firstSession.makeSnapshot())
        try await firstCoordinator.flush()

        let resumed = try await ProgressSessionLoader.open(
            fragmentID: firstFragmentID,
            puzzle: puzzle,
            store: store
        )
        guard case .restored(var resumedSession, let resumedGeneration) = resumed,
              resumedGeneration == 2,
              resumedSession.assistanceHistory.contains(.hint) else {
            throw CommandError.progressValidationFailed(
                "flush did not preserve the latest cells and assistance"
            )
        }

        let solutionEdits = puzzle.solution.cells.enumerated().compactMap { offset, colorID -> CellEdit? in
            guard let colorID else { return nil }
            return CellEdit(
                coordinate: CellCoordinate(
                    x: offset % puzzle.solution.width,
                    y: offset / puzzle.solution.width
                ),
                state: .filled(colorId: colorID)
            )
        }
        _ = try resumedSession.applyBatch(solutionEdits)
        let firstReceipt = try await firstCoordinator.complete(
            artworkID: "smoke-artwork",
            requiredFragmentKeys: requiredKeys,
            session: resumedSession
        )
        guard firstReceipt.newlyCompleted,
              firstReceipt.completedCount == 1,
              firstReceipt.totalCount == 2 else {
            throw CommandError.progressValidationFailed("first completion receipt is incorrect")
        }

        var secondSession = try GameSession(puzzle: puzzle)
        _ = try secondSession.applyBatch(solutionEdits)
        let secondCoordinator = try SessionAutosaveCoordinator(
            fragmentID: secondFragmentID,
            persistedGeneration: 0,
            store: store,
            throttleDelay: .seconds(60)
        )
        let finalReceipt = try await secondCoordinator.complete(
            artworkID: "smoke-artwork",
            requiredFragmentKeys: requiredKeys,
            session: secondSession
        )
        guard finalReceipt.newlyCompleted,
              finalReceipt.completedCount == 2,
              finalReceipt.totalCount == 2 else {
            throw CommandError.progressValidationFailed("final completion receipt is incorrect")
        }

        do {
            try await store.saveSession(
                fragmentID: firstFragmentID,
                snapshot: try resumedSession.makeSnapshot(),
                generation: 1,
                updatedAt: Date()
            )
            throw CommandError.progressValidationFailed("stale generation was accepted")
        } catch ProgressStoreError.staleGeneration {
            // Expected: a delayed autosave cannot overwrite the completion generation.
        }

        // A submit that reenters while completion awaits the Store must remain pending.
        let reentrantStore = ProgressSmokeStore(completionDelay: .milliseconds(50))
        let reentrantFragmentID = "smoke-fragment-reentrant"
        let reentrantKey = ProgressRecordKey(fragmentID: reentrantFragmentID, puzzle: puzzle)
        var preparedReentrantSession = try GameSession(puzzle: puzzle)
        _ = try preparedReentrantSession.applyBatch(solutionEdits)
        let reentrantSession = preparedReentrantSession
        let reentrantSnapshot = try reentrantSession.makeSnapshot()
        let reentrantCoordinator = try SessionAutosaveCoordinator(
            fragmentID: reentrantFragmentID,
            persistedGeneration: 0,
            store: reentrantStore,
            throttleDelay: .seconds(60)
        )
        let completionTask = Task {
            try await reentrantCoordinator.complete(
                artworkID: "smoke-reentrant-artwork",
                requiredFragmentKeys: [reentrantKey],
                session: reentrantSession
            )
        }
        while !(await reentrantStore.completionHasStarted()) { await Task.yield() }
        _ = try await reentrantCoordinator.submit(snapshot: reentrantSnapshot)
        _ = try await completionTask.value
        guard await reentrantCoordinator.hasPendingSave,
              await reentrantCoordinator.currentGeneration == 2 else {
            throw CommandError.progressValidationFailed(
                "completion erased a newer reentrant submission"
            )
        }
        try await reentrantCoordinator.flush()
        guard let reentrantRecord = try await reentrantStore.record(for: reentrantKey),
              reentrantRecord.generation == 2,
              reentrantRecord.completedAt != nil else {
            throw CommandError.progressValidationFailed(
                "reentrant submission did not preserve completion"
            )
        }

        // A failed durability barrier must leave enough state for an explicit retry.
        let retryStore = ProgressSmokeStore(failNextFlush: true)
        let retryFragmentID = "smoke-fragment-retry"
        let retryKey = ProgressRecordKey(fragmentID: retryFragmentID, puzzle: puzzle)
        let retryCoordinator = try SessionAutosaveCoordinator(
            fragmentID: retryFragmentID,
            persistedGeneration: 0,
            store: retryStore,
            throttleDelay: .seconds(60)
        )
        _ = try await retryCoordinator.submit(snapshot: reentrantSnapshot)
        do {
            try await retryCoordinator.flush()
            throw CommandError.progressValidationFailed("injected flush failure was not surfaced")
        } catch ProgressSmokeStoreError.injectedFlushFailure {
            guard await retryCoordinator.hasPendingSave else {
                throw CommandError.progressValidationFailed(
                    "flush failure discarded retry state"
                )
            }
        }
        try await retryCoordinator.flush()
        guard !(await retryCoordinator.hasPendingSave),
              try await retryStore.record(for: retryKey)?.generation == 1 else {
            throw CommandError.progressValidationFailed("flush retry did not become durable")
        }

        // Exact-current lookup must not decode corrupt sibling revisions first.
        let isolatedStore = ProgressSmokeStore(rejectCollectionReads: true)
        let isolatedFragmentID = "smoke-fragment-isolated"
        let isolatedKey = ProgressRecordKey(fragmentID: isolatedFragmentID, puzzle: puzzle)
        try await isolatedStore.saveSession(
            fragmentID: isolatedFragmentID,
            snapshot: reentrantSnapshot,
            generation: 7,
            updatedAt: Date()
        )
        let isolatedOpen = try await ProgressSessionLoader.open(
            fragmentID: isolatedFragmentID,
            puzzle: puzzle,
            store: isolatedStore
        )
        guard case .restored(_, let isolatedGeneration) = isolatedOpen,
              isolatedGeneration == 7,
              try await isolatedStore.record(for: isolatedKey) != nil else {
            throw CommandError.progressValidationFailed(
                "exact-current restore depended on sibling record decoding"
            )
        }

        print([
            "✓ Progress persistence smoke validation",
            "  coalesced autosave + explicit flush: passed",
            "  assistance-only durability: passed",
            "  restore generation: \(resumedGeneration)",
            "  first completion count: 1/2",
            "  final completion count: 2/2",
            "  stale generation rejection: passed",
            "  reentrant completion submission: preserved",
            "  failed flush retry state: preserved",
            "  exact-current restore isolation: passed",
            "  SwiftData adapter: conditionally compiled on Apple platforms",
        ].joined(separator: "\n"))
    }

    private static func validateAccess(artworkURL: URL) throws {
        let artwork = try JSONDecoder().decode(
            ArtworkDefinition.self,
            from: Data(contentsOf: artworkURL)
        )
        guard artwork.repairFragmentIDs.count == 4 else {
            throw CommandError.accessValidationFailed(
                "expected the cardinality-4 Artwork fixture"
            )
        }

        func replacingFragments(with fragmentIDs: [String]) -> ArtworkDefinition {
            ArtworkDefinition(
                schema: artwork.schema,
                id: artwork.id,
                revision: artwork.revision,
                museumID: artwork.museumID,
                galleryID: artwork.galleryID,
                repairFragmentIDs: fragmentIDs,
                blueprintID: artwork.blueprintID
            )
        }

        func matches(
            _ state: ArtworkAccessState,
            restored: Bool,
            blueprint: Bool,
            seal: Bool
        ) -> Bool {
            state.artworkRestored == restored
                && state.canUseArtworkBlueprint == blueprint
                && state.hasRestorerSeal == seal
        }

        let noEntitlement = ArtworkAccessEvaluator(
            entitlementResolver: AccessSmokeEntitlementResolver(museumIDs: [])
        )
        let noProgress = try noEntitlement.evaluate(
            artwork: artwork,
            completedFragmentIDs: []
        )
        guard matches(
            noProgress,
            restored: false,
            blueprint: false,
            seal: false
        ) else {
            throw CommandError.accessValidationFailed(
                "an untouched Artwork unexpectedly has access or completion"
            )
        }

        for omittedFragmentID in artwork.repairFragmentIDs {
            let completedIDs = Set(
                artwork.repairFragmentIDs.filter { $0 != omittedFragmentID }
            )
            let partial = try noEntitlement.evaluate(
                artwork: artwork,
                completedFragmentIDs: completedIDs
            )
            guard partial == noProgress else {
                throw CommandError.accessValidationFailed(
                    "Artwork restored before all configured Fragments completed"
                )
            }
        }

        let partialIDs = Set(artwork.repairFragmentIDs.dropLast())
        let matchingEntitlement = ArtworkAccessEvaluator(
            entitlementResolver: AccessSmokeEntitlementResolver(
                museumIDs: [artwork.museumID]
            )
        )
        let entitled = try matchingEntitlement.evaluate(
            artwork: artwork,
            completedFragmentIDs: partialIDs
        )
        guard matches(
            entitled,
            restored: false,
            blueprint: true,
            seal: false
        ) else {
            throw CommandError.accessValidationFailed(
                "Museum entitlement changed restoration or seal state"
            )
        }

        let otherEntitlement = ArtworkAccessEvaluator(
            entitlementResolver: AccessSmokeEntitlementResolver(
                museumIDs: ["another-museum"]
            )
        )
        guard try otherEntitlement.evaluate(
            artwork: artwork,
            completedFragmentIDs: partialIDs
        ) == noProgress else {
            throw CommandError.accessValidationFailed(
                "an unrelated Museum entitlement granted Blueprint access"
            )
        }

        var completedIDs = Set(artwork.repairFragmentIDs)
        completedIDs.insert("unrelated-fragment")
        let restored = try noEntitlement.evaluate(
            artwork: artwork,
            completedFragmentIDs: completedIDs
        )
        guard matches(
            restored,
            restored: true,
            blueprint: true,
            seal: true
        ) else {
            throw CommandError.accessValidationFailed(
                "complete Artwork did not derive Blueprint access and seal"
            )
        }

        let singleFragmentArtwork = replacingFragments(with: [artwork.repairFragmentIDs[0]])
        let completedSingleFragment = try noEntitlement.evaluate(
            artwork: singleFragmentArtwork,
            completedFragmentIDs: [artwork.repairFragmentIDs[0]]
        )
        guard try noEntitlement.evaluate(
            artwork: singleFragmentArtwork,
            completedFragmentIDs: []
        ) == noProgress,
        matches(
            completedSingleFragment,
            restored: true,
            blueprint: true,
            seal: true
        ) else {
            throw CommandError.accessValidationFailed(
                "single-Fragment Artwork completion is incorrect"
            )
        }

        for invalidCount in [0, 5] {
            let invalidArtwork = replacingFragments(
                with: (0..<invalidCount).map { "invalid-fragment-\($0)" }
            )
            do {
                _ = try noEntitlement.evaluate(
                    artwork: invalidArtwork,
                    completedFragmentIDs: []
                )
                throw CommandError.accessValidationFailed(
                    "accepted Artwork Fragment count \(invalidCount)"
                )
            } catch ArtworkRuleError.invalidRepairFragmentCount(let actual)
                where actual == invalidCount {
                // Expected: count is validated before allSatisfy.
            }
        }

        print([
            "✓ Artwork access smoke validation",
            "  Fragment cardinality guard: 0/5 rejected, 1/4 accepted",
            "  partial completion: no restoration, Blueprint, or seal",
            "  matching Museum entitlement: Blueprint only",
            "  unrelated Museum entitlement: no access",
            "  complete Artwork: restoration + Blueprint + seal",
            "  extra completed Fragment IDs: ignored",
        ].joined(separator: "\n"))
    }
}

private struct AccessSmokeEntitlementResolver: MuseumBlueprintEntitlementResolving {
    let museumIDs: Set<String>

    func hasMuseumBlueprintEntitlement(_ museumID: String) -> Bool {
        museumIDs.contains(museumID)
    }
}

private enum ProgressSmokeStoreError: Error {
    case injectedFlushFailure
}

/// Fault-injecting adapter used only by the CLI persistence smoke validation.
private actor ProgressSmokeStore: ProgressStore {
    private let base = InMemoryProgressStore()
    private let completionDelay: Duration?
    private let rejectCollectionReads: Bool
    private var shouldFailNextFlush: Bool
    private var didStartCompletion = false

    init(
        completionDelay: Duration? = nil,
        failNextFlush: Bool = false,
        rejectCollectionReads: Bool = false
    ) {
        self.completionDelay = completionDelay
        self.shouldFailNextFlush = failNextFlush
        self.rejectCollectionReads = rejectCollectionReads
    }

    func completionHasStarted() -> Bool { didStartCompletion }

    func records(for fragmentID: String) async throws -> [FragmentProgressRecord] {
        if rejectCollectionReads {
            throw ProgressStoreError.persistentRecordCorrupt("injected corrupt sibling")
        }
        return try await base.records(for: fragmentID)
    }

    func record(for key: ProgressRecordKey) async throws -> FragmentProgressRecord? {
        try await base.record(for: key)
    }

    func records(
        for keys: Set<ProgressRecordKey>
    ) async throws -> [ProgressRecordKey: FragmentProgressRecord] {
        try await base.records(for: keys)
    }

    func saveSession(
        fragmentID: String,
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date
    ) async throws {
        try await base.saveSession(
            fragmentID: fragmentID,
            snapshot: snapshot,
            generation: generation,
            updatedAt: updatedAt
        )
    }

    func completeFragment(
        _ command: CompleteFragmentCommand
    ) async throws -> FragmentCompletionReceipt {
        didStartCompletion = true
        if let completionDelay { try await Task.sleep(for: completionDelay) }
        return try await base.completeFragment(command)
    }

    func flush() async throws {
        if shouldFailNextFlush {
            shouldFailNextFlush = false
            throw ProgressSmokeStoreError.injectedFlushFailure
        }
        try await base.flush()
    }
}

enum CommandError: Error, CustomStringConvertible {
    case usage
    case invalidDirectory(String)
    case noPuzzleDefinitions(String)
    case sessionValidationFailed(String)
    case progressValidationFailed(String)
    case accessValidationFailed(String)
    case productValidationFailed(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage:\n  kanaka-content validate-puzzle <puzzle-definition.json>\n  kanaka-content validate-puzzles <directory>\n  kanaka-content validate-content <directory>\n  kanaka-content validate-session <puzzle-definition.json>\n  kanaka-content validate-progress <puzzle-definition.json>\n  kanaka-content validate-access <artwork.json>\n  kanaka-content validate-product-flow <content-directory>"
        case .invalidDirectory(let path):
            return "Not a readable directory: \(path)"
        case .noPuzzleDefinitions(let path):
            return "No puzzle-definition.json files found under: \(path)"
        case .sessionValidationFailed(let reason):
            return "GameSession validation failed: \(reason)"
        case .progressValidationFailed(let reason):
            return "Progress validation failed: \(reason)"
        case .accessValidationFailed(let reason):
            return "Artwork access validation failed: \(reason)"
        case .productValidationFailed(let reason):
            return "Product flow validation failed: \(reason)"
        }
    }
}
