public struct LogicalSolveReport: Equatable, Sendable {
    public let solverVersion: String
    public let solved: Bool
    public let cells: [Int?]
    public let steps: [LogicalStep]

    public init(solverVersion: String, solved: Bool, cells: [Int?], steps: [LogicalStep]) {
        self.solverVersion = solverVersion
        self.solved = solved
        self.cells = cells
        self.steps = steps
    }
}

public struct LogicalStep: Equatable, Sendable {
    public let technique: LogicalTechnique
    public let orientation: LineOrientation
    public let lineIndex: Int
    public let deductions: [CellDeduction]

    public init(
        technique: LogicalTechnique,
        orientation: LineOrientation,
        lineIndex: Int,
        deductions: [CellDeduction]
    ) {
        self.technique = technique
        self.orientation = orientation
        self.lineIndex = lineIndex
        self.deductions = deductions
    }
}

public enum LogicalTechnique: String, Sendable {
    case lineCandidateIntersection
}

public enum LineOrientation: String, Sendable {
    case row
    case column
}

public struct CellDeduction: Equatable, Sendable {
    public let x: Int
    public let y: Int
    /// `0` means excluded; positive values are palette color indices.
    public let value: Int

    public init(x: Int, y: Int, value: Int) {
        self.x = x
        self.y = y
        self.value = value
    }
}

public enum LogicalSolverError: Error, Equatable, CustomStringConvertible {
    case invalidDimensions
    case contradiction(orientation: LineOrientation, lineIndex: Int)
    case conflictingDeduction(x: Int, y: Int, existing: Int, proposed: Int)

    public var description: String {
        switch self {
        case .invalidDimensions:
            return "Logical solver received invalid dimensions or clue counts"
        case .contradiction(let orientation, let lineIndex):
            return "No candidates remain for \(orientation.rawValue) \(lineIndex)"
        case .conflictingDeduction(let x, let y, let existing, let proposed):
            return "Conflicting deduction at (\(x), \(y)): \(existing) vs \(proposed)"
        }
    }
}

public enum LogicalColoredNonogramSolver {
    public static func solve(
        width: Int,
        height: Int,
        clues: PuzzleClues,
        initialCells: [Int?]? = nil
    ) throws -> LogicalSolveReport {
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(width),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(height),
              clues.rows.count == height,
              clues.columns.count == width else {
            throw LogicalSolverError.invalidDimensions
        }

        let cellCount = width * height
        var cells = initialCells ?? Array(repeating: nil, count: cellCount)
        guard cells.count == cellCount else {
            throw LogicalSolverError.invalidDimensions
        }
        var steps: [LogicalStep] = []

        func assign(_ deductions: [CellDeduction]) throws -> [CellDeduction] {
            var newlyAssigned: [CellDeduction] = []
            for deduction in deductions {
                let offset = deduction.y * width + deduction.x
                if let existing = cells[offset] {
                    guard existing == deduction.value else {
                        throw LogicalSolverError.conflictingDeduction(
                            x: deduction.x,
                            y: deduction.y,
                            existing: existing,
                            proposed: deduction.value
                        )
                    }
                } else {
                    cells[offset] = deduction.value
                    newlyAssigned.append(deduction)
                }
            }
            return newlyAssigned
        }

        while true {
            var changed = false

            for y in 0..<height {
                let analysis = LineConstraintAnalyzer.analyze(
                    length: width,
                    clues: clues.rows[y],
                    knownCells: (0..<width).map { cells[y * width + $0] }
                )
                guard analysis.isFeasible else {
                    throw LogicalSolverError.contradiction(orientation: .row, lineIndex: y)
                }
                let deductions = analysis.possibleValues.enumerated().compactMap { x, values in
                    values.count == 1
                        ? CellDeduction(x: x, y: y, value: values.first!)
                        : nil
                }
                let newDeductions = try assign(deductions)
                if !newDeductions.isEmpty {
                    changed = true
                    steps.append(LogicalStep(
                        technique: .lineCandidateIntersection,
                        orientation: .row,
                        lineIndex: y,
                        deductions: newDeductions
                    ))
                }
            }

            for x in 0..<width {
                let analysis = LineConstraintAnalyzer.analyze(
                    length: height,
                    clues: clues.columns[x],
                    knownCells: (0..<height).map { cells[$0 * width + x] }
                )
                guard analysis.isFeasible else {
                    throw LogicalSolverError.contradiction(orientation: .column, lineIndex: x)
                }
                let deductions = analysis.possibleValues.enumerated().compactMap { y, values in
                    values.count == 1
                        ? CellDeduction(x: x, y: y, value: values.first!)
                        : nil
                }
                let newDeductions = try assign(deductions)
                if !newDeductions.isEmpty {
                    changed = true
                    steps.append(LogicalStep(
                        technique: .lineCandidateIntersection,
                        orientation: .column,
                        lineIndex: x,
                        deductions: newDeductions
                    ))
                }
            }

            // Even when the board becomes full during this pass, run one unchanged
            // pass so every row and column is revalidated against the same final grid.
            if !changed { break }
        }

        return LogicalSolveReport(
            solverVersion: KanakaCoreVersion.logicalSolver,
            solved: cells.allSatisfy { $0 != nil },
            cells: cells,
            steps: steps
        )
    }
}
