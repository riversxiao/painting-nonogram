import Foundation
import KanakaContentKit
import KanakaCore

@main
enum KanakaContentCommand {
    static func main() {
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
                let report = try ContentBundleValidator.validate(
                    directoryURL: URL(fileURLWithPath: arguments[1])
                )
                print(report.formattedDescription)
            case "validate-session":
                try validateSession(
                    puzzleURL: URL(fileURLWithPath: arguments[1])
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
}

enum CommandError: Error, CustomStringConvertible {
    case usage
    case invalidDirectory(String)
    case noPuzzleDefinitions(String)
    case sessionValidationFailed(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage:\n  kanaka-content validate-puzzle <puzzle-definition.json>\n  kanaka-content validate-puzzles <directory>\n  kanaka-content validate-content <directory>\n  kanaka-content validate-session <puzzle-definition.json>"
        case .invalidDirectory(let path):
            return "Not a readable directory: \(path)"
        case .noPuzzleDefinitions(let path):
            return "No puzzle-definition.json files found under: \(path)"
        case .sessionValidationFailed(let reason):
            return "GameSession validation failed: \(reason)"
        }
    }
}
