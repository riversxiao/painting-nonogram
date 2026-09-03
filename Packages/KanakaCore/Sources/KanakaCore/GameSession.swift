public struct CellCoordinate: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct CellEdit: Equatable, Sendable {
    public let coordinate: CellCoordinate
    public let state: CellState

    public init(coordinate: CellCoordinate, state: CellState) {
        self.coordinate = coordinate
        self.state = state
    }
}

public enum AssistanceSource: String, Codable, CaseIterable, Hashable, Sendable {
    case authoredPrefill
    case hint
    case dynamicReveal
    case accessibilityPrefill
}

public enum PuzzleCompletionStatus: String, Codable, Equatable, Sendable {
    case incomplete
    case completed
    case completedWithoutHints
}

public struct SessionChange: Equatable, Sendable {
    public let changedCoordinates: [CellCoordinate]
    public let previousCompletionStatus: PuzzleCompletionStatus
    public let completionStatus: PuzzleCompletionStatus
    public let assistanceAdded: AssistanceSource?
    public let createdHistoryEntry: Bool

    public init(
        changedCoordinates: [CellCoordinate],
        previousCompletionStatus: PuzzleCompletionStatus,
        completionStatus: PuzzleCompletionStatus,
        assistanceAdded: AssistanceSource?,
        createdHistoryEntry: Bool
    ) {
        self.changedCoordinates = changedCoordinates
        self.previousCompletionStatus = previousCompletionStatus
        self.completionStatus = completionStatus
        self.assistanceAdded = assistanceAdded
        self.createdHistoryEntry = createdHistoryEntry
    }
}

public enum GameSessionError: Error, Equatable, CustomStringConvertible {
    case invalidPuzzle(String)
    case duplicateCoordinate(CellCoordinate)
    case coordinateOutOfBounds(CellCoordinate)
    case lockedPrefilledCell(CellCoordinate)
    case unknownColorId(String)

    public var description: String {
        switch self {
        case .invalidPuzzle(let reason):
            return "Invalid puzzle for GameSession: \(reason)"
        case .duplicateCoordinate(let coordinate):
            return "Batch contains duplicate coordinate (\(coordinate.x), \(coordinate.y))"
        case .coordinateOutOfBounds(let coordinate):
            return "Coordinate (\(coordinate.x), \(coordinate.y)) is outside the board"
        case .lockedPrefilledCell(let coordinate):
            return "Authored prefilled cell (\(coordinate.x), \(coordinate.y)) is locked"
        case .unknownColorId(let colorId):
            return "Cell edit references unknown colorId: \(colorId)"
        }
    }
}

public struct GameSession: Sendable {
    public let puzzleID: String
    public let puzzleRevision: Int
    public let puzzleSemanticHash: String
    public let width: Int
    public let height: Int
    public let palette: [PuzzleColor]

    public private(set) var cells: [CellState]
    public private(set) var assistanceHistory: Set<AssistanceSource>

    private let solution: [String?]
    private let lockedCoordinates: Set<CellCoordinate>
    private var undoStack: [SessionTransaction]
    private var redoStack: [SessionTransaction]

    public init(puzzle: PuzzleDefinition) throws {
        guard !puzzle.id.isEmpty, puzzle.revision >= 1, !puzzle.semanticHash.isEmpty else {
            throw GameSessionError.invalidPuzzle("identity, revision, and semantic hash are required")
        }
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(puzzle.solution.width),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(puzzle.solution.height),
              puzzle.solution.origin == "top-left",
              puzzle.solution.order == "row-major" else {
            throw GameSessionError.invalidPuzzle("unsupported dimensions or grid convention")
        }
        let cellCount = puzzle.solution.width * puzzle.solution.height
        guard puzzle.solution.cells.count == cellCount else {
            throw GameSessionError.invalidPuzzle("semantic grid cell count does not match dimensions")
        }

        let paletteByID: [String: PuzzleColor]
        do {
            paletteByID = try CellStateCodecV1.validatedPaletteByID(puzzle.palette)
        } catch {
            throw GameSessionError.invalidPuzzle(String(describing: error))
        }
        guard puzzle.solution.cells.allSatisfy({ colorID in
            colorID.map { paletteByID[$0] != nil } ?? true
        }) else {
            throw GameSessionError.invalidPuzzle("semantic grid references an unknown colorId")
        }
        if puzzle.kind == .formal, !puzzle.prefilledCells.isEmpty {
            throw GameSessionError.invalidPuzzle("formal puzzles cannot contain authored prefilled cells")
        }

        var initialCells = Array(repeating: CellState.unknown, count: cellCount)
        var locked = Set<CellCoordinate>()
        for prefilled in puzzle.prefilledCells {
            let coordinate = CellCoordinate(x: prefilled.x, y: prefilled.y)
            guard Self.contains(coordinate, width: puzzle.solution.width, height: puzzle.solution.height) else {
                throw GameSessionError.coordinateOutOfBounds(coordinate)
            }
            guard locked.insert(coordinate).inserted else {
                throw GameSessionError.duplicateCoordinate(coordinate)
            }
            let offset = prefilled.y * puzzle.solution.width + prefilled.x
            switch prefilled.state {
            case .excluded:
                guard prefilled.colorId == nil, puzzle.solution.cells[offset] == nil else {
                    throw GameSessionError.invalidPuzzle("excluded prefill must match an empty answer cell")
                }
                initialCells[offset] = .excluded
            case .filled:
                guard let colorID = prefilled.colorId,
                      paletteByID[colorID] != nil,
                      puzzle.solution.cells[offset] == colorID else {
                    throw GameSessionError.invalidPuzzle("filled prefill must match the answer colorId")
                }
                initialCells[offset] = .filled(colorId: colorID)
            }
        }

        puzzleID = puzzle.id
        puzzleRevision = puzzle.revision
        puzzleSemanticHash = puzzle.semanticHash
        width = puzzle.solution.width
        height = puzzle.solution.height
        palette = puzzle.palette.sorted { $0.colorIndex < $1.colorIndex }
        solution = puzzle.solution.cells
        cells = initialCells
        lockedCoordinates = locked
        assistanceHistory = puzzle.prefilledCells.isEmpty ? [] : [.authoredPrefill]
        undoStack = []
        redoStack = []
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var isComplete: Bool { Self.isComplete(cells: cells, solution: solution) }

    public var completionStatus: PuzzleCompletionStatus {
        guard isComplete else { return .incomplete }
        return assistanceHistory.isEmpty ? .completedWithoutHints : .completed
    }

    public var completedWithoutHints: Bool {
        completionStatus == .completedWithoutHints
    }

    public func cell(at coordinate: CellCoordinate) throws -> CellState {
        guard Self.contains(coordinate, width: width, height: height) else {
            throw GameSessionError.coordinateOutOfBounds(coordinate)
        }
        return cells[offset(for: coordinate)]
    }

    public func isLocked(_ coordinate: CellCoordinate) -> Bool {
        lockedCoordinates.contains(coordinate)
    }

    /// Records help that was actually delivered to the player. This fact is intentionally not undoable.
    @discardableResult
    public mutating func recordAssistance(_ source: AssistanceSource) -> SessionChange {
        let previousStatus = completionStatus
        let inserted = assistanceHistory.insert(source).inserted
        return SessionChange(
            changedCoordinates: [],
            previousCompletionStatus: previousStatus,
            completionStatus: completionStatus,
            assistanceAdded: inserted ? source : nil,
            createdHistoryEntry: false
        )
    }

    /// Applies one atomic user transaction. A tap is a one-edit batch; a drag is a multi-edit batch.
    @discardableResult
    public mutating func applyBatch(
        _ edits: [CellEdit],
        assistance: AssistanceSource? = nil
    ) throws -> SessionChange {
        var seen = Set<CellCoordinate>()
        var mutations: [CellMutation] = []

        for edit in edits {
            guard seen.insert(edit.coordinate).inserted else {
                throw GameSessionError.duplicateCoordinate(edit.coordinate)
            }
            guard Self.contains(edit.coordinate, width: width, height: height) else {
                throw GameSessionError.coordinateOutOfBounds(edit.coordinate)
            }
            guard !lockedCoordinates.contains(edit.coordinate) else {
                throw GameSessionError.lockedPrefilledCell(edit.coordinate)
            }
            if case .filled(let colorID) = edit.state,
               !palette.contains(where: { $0.colorId == colorID }) {
                throw GameSessionError.unknownColorId(colorID)
            }

            let index = offset(for: edit.coordinate)
            let before = cells[index]
            if before != edit.state {
                mutations.append(CellMutation(
                    coordinate: edit.coordinate,
                    before: before,
                    after: edit.state
                ))
            }
        }

        let previousStatus = completionStatus
        let assistanceAdded = assistance.flatMap { source in
            assistanceHistory.insert(source).inserted ? source : nil
        }

        if !mutations.isEmpty {
            for mutation in mutations {
                cells[offset(for: mutation.coordinate)] = mutation.after
            }
            undoStack.append(SessionTransaction(mutations: mutations))
            redoStack.removeAll(keepingCapacity: true)
        }

        return SessionChange(
            changedCoordinates: mutations.map(\.coordinate),
            previousCompletionStatus: previousStatus,
            completionStatus: completionStatus,
            assistanceAdded: assistanceAdded,
            createdHistoryEntry: !mutations.isEmpty
        )
    }

    @discardableResult
    public mutating func undo() -> SessionChange? {
        guard let transaction = undoStack.popLast() else { return nil }
        let previousStatus = completionStatus
        for mutation in transaction.mutations {
            cells[offset(for: mutation.coordinate)] = mutation.before
        }
        redoStack.append(transaction)
        return SessionChange(
            changedCoordinates: transaction.mutations.map(\.coordinate),
            previousCompletionStatus: previousStatus,
            completionStatus: completionStatus,
            assistanceAdded: nil,
            createdHistoryEntry: false
        )
    }

    @discardableResult
    public mutating func redo() -> SessionChange? {
        guard let transaction = redoStack.popLast() else { return nil }
        let previousStatus = completionStatus
        for mutation in transaction.mutations {
            cells[offset(for: mutation.coordinate)] = mutation.after
        }
        undoStack.append(transaction)
        return SessionChange(
            changedCoordinates: transaction.mutations.map(\.coordinate),
            previousCompletionStatus: previousStatus,
            completionStatus: completionStatus,
            assistanceAdded: nil,
            createdHistoryEntry: false
        )
    }

    mutating func loadRestoredState(
        cells restoredCells: [CellState],
        assistance restoredAssistance: Set<AssistanceSource>
    ) throws {
        guard restoredCells.count == cells.count else {
            throw GameSessionError.invalidPuzzle("restored cell count does not match the board")
        }
        for coordinate in lockedCoordinates {
            let index = offset(for: coordinate)
            guard restoredCells[index] == cells[index] else {
                throw GameSessionError.invalidPuzzle(
                    "restored data changes locked authored prefill at (\(coordinate.x), \(coordinate.y))"
                )
            }
        }
        cells = restoredCells
        assistanceHistory = restoredAssistance
        if !lockedCoordinates.isEmpty {
            assistanceHistory.insert(.authoredPrefill)
        }
        undoStack.removeAll(keepingCapacity: false)
        redoStack.removeAll(keepingCapacity: false)
    }

    private func offset(for coordinate: CellCoordinate) -> Int {
        coordinate.y * width + coordinate.x
    }

    private static func contains(
        _ coordinate: CellCoordinate,
        width: Int,
        height: Int
    ) -> Bool {
        (0..<width).contains(coordinate.x) && (0..<height).contains(coordinate.y)
    }

    private static func isComplete(cells: [CellState], solution: [String?]) -> Bool {
        zip(cells, solution).allSatisfy { state, answer in
            switch (state, answer) {
            case (.filled(let actual), .some(let expected)):
                return actual == expected
            case (.unknown, .none), (.excluded, .none):
                return true
            default:
                return false
            }
        }
    }
}

private struct CellMutation: Equatable, Sendable {
    let coordinate: CellCoordinate
    let before: CellState
    let after: CellState
}

private struct SessionTransaction: Equatable, Sendable {
    let mutations: [CellMutation]
}
