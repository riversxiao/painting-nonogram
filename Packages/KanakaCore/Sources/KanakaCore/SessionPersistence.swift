import Foundation

public struct SavedSessionMetadata: Codable, Equatable, Sendable {
    public let codecVersion: Int
    public let puzzleID: String
    public let puzzleRevision: Int
    public let puzzleSemanticHash: String
    public let width: Int
    public let height: Int
    public let cellCount: Int
    /// Stable semantic color IDs in ascending 1-based colorIndex order.
    public let paletteColorIDsByIndex: [String]

    public init(
        codecVersion: Int,
        puzzleID: String,
        puzzleRevision: Int,
        puzzleSemanticHash: String,
        width: Int,
        height: Int,
        cellCount: Int,
        paletteColorIDsByIndex: [String]
    ) {
        self.codecVersion = codecVersion
        self.puzzleID = puzzleID
        self.puzzleRevision = puzzleRevision
        self.puzzleSemanticHash = puzzleSemanticHash
        self.width = width
        self.height = height
        self.cellCount = cellCount
        self.paletteColorIDsByIndex = paletteColorIDsByIndex
    }
}

public struct SavedSessionSnapshot: Codable, Equatable, Sendable {
    public let metadata: SavedSessionMetadata
    public let encodedCells: Data
    public let assistanceHistory: [AssistanceSource]

    public init(
        metadata: SavedSessionMetadata,
        encodedCells: Data,
        assistanceHistory: [AssistanceSource]
    ) {
        self.metadata = metadata
        self.encodedCells = encodedCells
        self.assistanceHistory = assistanceHistory
    }
}

public enum RestoreMismatch: Equatable, Sendable {
    case codecVersionChanged(saved: Int, current: Int)
    case puzzleIdentityChanged(saved: String, current: String)
    case semanticHashChanged(saved: String, current: String)
    case revisionChangedSemanticHashUnchanged(saved: Int, current: Int)
    case dimensionsChanged(savedWidth: Int, savedHeight: Int, currentWidth: Int, currentHeight: Int)
    case paletteMappingChanged(saved: [String], current: [String])
}

public enum SavedStateCorruption: Equatable, Sendable {
    case invalidDimensions(width: Int, height: Int, cellCount: Int)
    case encodedCellCount(expected: Int, actual: Int)
    case duplicateAssistanceSource(AssistanceSource)
    case invalidCellEncoding(String)
}

public enum SessionRestoreDecision: Equatable, Sendable {
    case compatible
    case requiresMigration(RestoreMismatch)
    case corrupt(SavedStateCorruption)
}

public enum SessionRestoreEvaluator {
    public static func evaluate(
        snapshot: SavedSessionSnapshot,
        current puzzle: PuzzleDefinition
    ) -> SessionRestoreDecision {
        let metadata = snapshot.metadata
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(metadata.width),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(metadata.height) else {
            return .corrupt(.invalidDimensions(
                width: metadata.width,
                height: metadata.height,
                cellCount: metadata.cellCount
            ))
        }
        let (calculatedCellCount, overflow) = metadata.width.multipliedReportingOverflow(by: metadata.height)
        guard !overflow, calculatedCellCount == metadata.cellCount else {
            return .corrupt(.invalidDimensions(
                width: metadata.width,
                height: metadata.height,
                cellCount: metadata.cellCount
            ))
        }
        guard snapshot.encodedCells.count == metadata.cellCount else {
            return .corrupt(.encodedCellCount(
                expected: metadata.cellCount,
                actual: snapshot.encodedCells.count
            ))
        }
        var seenAssistance = Set<AssistanceSource>()
        for source in snapshot.assistanceHistory where !seenAssistance.insert(source).inserted {
            return .corrupt(.duplicateAssistanceSource(source))
        }

        guard metadata.codecVersion == CellStateCodecV1.version else {
            return .requiresMigration(.codecVersionChanged(
                saved: metadata.codecVersion,
                current: CellStateCodecV1.version
            ))
        }
        guard metadata.puzzleID == puzzle.id else {
            return .requiresMigration(.puzzleIdentityChanged(
                saved: metadata.puzzleID,
                current: puzzle.id
            ))
        }
        guard metadata.puzzleSemanticHash == puzzle.semanticHash else {
            return .requiresMigration(.semanticHashChanged(
                saved: metadata.puzzleSemanticHash,
                current: puzzle.semanticHash
            ))
        }
        guard metadata.puzzleRevision == puzzle.revision else {
            return .requiresMigration(.revisionChangedSemanticHashUnchanged(
                saved: metadata.puzzleRevision,
                current: puzzle.revision
            ))
        }
        guard metadata.width == puzzle.solution.width,
              metadata.height == puzzle.solution.height else {
            return .requiresMigration(.dimensionsChanged(
                savedWidth: metadata.width,
                savedHeight: metadata.height,
                currentWidth: puzzle.solution.width,
                currentHeight: puzzle.solution.height
            ))
        }

        let currentPalette = puzzle.palette
            .sorted { $0.colorIndex < $1.colorIndex }
            .map(\.colorId)
        guard metadata.paletteColorIDsByIndex == currentPalette else {
            return .requiresMigration(.paletteMappingChanged(
                saved: metadata.paletteColorIDsByIndex,
                current: currentPalette
            ))
        }

        do {
            _ = try CellStateCodecV1.decode(
                snapshot.encodedCells,
                expectedCellCount: metadata.cellCount,
                palette: puzzle.palette
            )
        } catch {
            return .corrupt(.invalidCellEncoding(String(describing: error)))
        }
        return .compatible
    }
}

public enum SessionRestoreError: Error, Equatable, CustomStringConvertible {
    case rejected(SessionRestoreDecision)
    case invalidRestoredState(String)

    public var description: String {
        switch self {
        case .rejected(let decision):
            return "Saved session cannot be restored without an explicit policy decision: \(decision)"
        case .invalidRestoredState(let reason):
            return "Saved session state is invalid: \(reason)"
        }
    }
}

public extension GameSession {
    func makeSnapshot() throws -> SavedSessionSnapshot {
        let sortedPalette = palette.sorted { $0.colorIndex < $1.colorIndex }
        return SavedSessionSnapshot(
            metadata: SavedSessionMetadata(
                codecVersion: CellStateCodecV1.version,
                puzzleID: puzzleID,
                puzzleRevision: puzzleRevision,
                puzzleSemanticHash: puzzleSemanticHash,
                width: width,
                height: height,
                cellCount: cells.count,
                paletteColorIDsByIndex: sortedPalette.map(\.colorId)
            ),
            encodedCells: try CellStateCodecV1.encode(cells, palette: sortedPalette),
            assistanceHistory: assistanceHistory.sorted { $0.rawValue < $1.rawValue }
        )
    }

    static func restore(
        puzzle: PuzzleDefinition,
        from snapshot: SavedSessionSnapshot
    ) throws -> GameSession {
        let decision = SessionRestoreEvaluator.evaluate(snapshot: snapshot, current: puzzle)
        guard decision == .compatible else {
            throw SessionRestoreError.rejected(decision)
        }

        let restoredCells: [CellState]
        do {
            restoredCells = try CellStateCodecV1.decode(
                snapshot.encodedCells,
                expectedCellCount: snapshot.metadata.cellCount,
                palette: puzzle.palette
            )
        } catch {
            throw SessionRestoreError.invalidRestoredState(String(describing: error))
        }

        var session = try GameSession(puzzle: puzzle)
        do {
            try session.loadRestoredState(
                cells: restoredCells,
                assistance: Set(snapshot.assistanceHistory)
            )
        } catch {
            throw SessionRestoreError.invalidRestoredState(String(describing: error))
        }
        return session
    }
}
