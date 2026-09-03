import Foundation
import KanakaCore

public struct PuzzleValidationReport: Sendable {
    public let puzzleID: String
    public let revision: Int
    public let width: Int
    public let height: Int
    public let colorCount: Int
    public let semanticHash: String
    public let exactSolutionCount: Int
    public let logicalSolverVersion: String
    public let logicalSteps: [LogicalStep]
    public let usedPrefilledCells: Bool

    public var formattedDescription: String {
        let summary = [
            "✓ \(puzzleID) revision \(revision)",
            "  schema: \(KanakaCoreVersion.puzzleSchema)",
            "  board: \(width)×\(height), colors: \(colorCount)",
            "  semantic hash: \(semanticHash)",
            "  exact colored solutions: \(exactSolutionCount)",
            "  pure logic: solved in \(logicalSteps.count) steps (\(logicalSolverVersion))",
        ]
        let details = logicalSteps.enumerated().map { index, step in
            let deductions = step.deductions.map { deduction in
                "(\(deduction.x),\(deduction.y))=\(deduction.value == 0 ? "empty" : "color[\(deduction.value)]")"
            }.joined(separator: ", ")
            return "    \(index + 1). \(step.orientation.rawValue)[\(step.lineIndex)] \(step.technique.rawValue): \(deductions)"
        }
        return (summary + details + [
            "  prefilled assistance: \(usedPrefilledCells ? "yes" : "no")",
        ]).joined(separator: "\n")
    }
}

public enum PuzzleValidationError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(String)
    case invalidIdentity
    case unsupportedRulesVersion(String)
    case unsupportedSolverVersion(String)
    case invalidDimensions
    case invalidGridConvention
    case invalidCellCount(expected: Int, actual: Int)
    case invalidPalette(String)
    case invalidClue(String)
    case formalPuzzleContainsPrefilledCells
    case invalidPrefilledCell(String)
    case clueMismatch
    case semanticHashMismatch(expected: String, actual: String)
    case exactSolutionCount(Int)
    case exactSolutionDoesNotMatchSemanticGrid
    case notPureLogicSolvable(solverVersion: String)
    case logicalSolutionDoesNotMatchSemanticGrid

    public var description: String {
        switch self {
        case .unsupportedSchema(let schema): return "Unsupported puzzle schema: \(schema)"
        case .invalidIdentity: return "Puzzle id must be non-empty and revision must be at least 1"
        case .unsupportedRulesVersion(let version): return "Unsupported rules version: \(version)"
        case .unsupportedSolverVersion(let version): return "Unsupported solver version: \(version)"
        case .invalidDimensions: return "Puzzle dimensions must be in 1...\(KanakaCoreLimits.maximumBoardDimension)"
        case .invalidGridConvention: return "Puzzle grid must use top-left origin and row-major order"
        case .invalidCellCount(let expected, let actual): return "Expected \(expected) solution cells, found \(actual)"
        case .invalidPalette(let reason): return "Invalid palette: \(reason)"
        case .invalidClue(let reason): return "Invalid clue: \(reason)"
        case .formalPuzzleContainsPrefilledCells: return "Formal puzzles must not contain prefilled cells"
        case .invalidPrefilledCell(let reason): return "Invalid prefilled cell: \(reason)"
        case .clueMismatch: return "Declared clues do not match the semantic solution grid"
        case .semanticHashMismatch(let expected, let actual): return "Semantic hash mismatch; expected \(expected), found \(actual)"
        case .exactSolutionCount(let count): return "Expected exactly one colored solution, found \(count >= 2 ? "at least 2" : String(count))"
        case .exactSolutionDoesNotMatchSemanticGrid: return "The unique clue solution does not match the semantic grid"
        case .notPureLogicSolvable(let version): return "Puzzle is not solvable by pure logic solver \(version)"
        case .logicalSolutionDoesNotMatchSemanticGrid: return "The logical solution does not match the semantic grid"
        }
    }
}

public enum PuzzleContentValidator {
    public static func validate(contentsOf url: URL) throws -> PuzzleValidationReport {
        let data = try Data(contentsOf: url)
        let puzzle = try JSONDecoder().decode(PuzzleDefinition.self, from: data)
        return try validate(puzzle)
    }

    public static func validate(_ puzzle: PuzzleDefinition) throws -> PuzzleValidationReport {
        try validateStructure(puzzle)
        let indexedSolution = try puzzle.indexedSolution()
        let generatedClues = ClueGenerator.generate(
            width: puzzle.solution.width,
            height: puzzle.solution.height,
            cells: indexedSolution
        )
        guard generatedClues == puzzle.clues else {
            throw PuzzleValidationError.clueMismatch
        }

        let actualHash = PuzzleSemanticHasher.hash(puzzle)
        guard actualHash == puzzle.semanticHash else {
            throw PuzzleValidationError.semanticHashMismatch(
                expected: actualHash,
                actual: puzzle.semanticHash
            )
        }

        let initialCells = try puzzle.indexedPrefilledCells()
        let exact = ExactColoredNonogramSolver.solve(
            width: puzzle.solution.width,
            height: puzzle.solution.height,
            clues: puzzle.clues,
            initialCells: initialCells
        )
        guard exact.solutionCount == 1 else {
            throw PuzzleValidationError.exactSolutionCount(exact.solutionCount)
        }
        guard exact.firstSolution == indexedSolution else {
            throw PuzzleValidationError.exactSolutionDoesNotMatchSemanticGrid
        }

        let logical = try LogicalColoredNonogramSolver.solve(
            width: puzzle.solution.width,
            height: puzzle.solution.height,
            clues: puzzle.clues,
            initialCells: initialCells
        )
        guard logical.solved else {
            throw PuzzleValidationError.notPureLogicSolvable(solverVersion: puzzle.solverVersion)
        }
        guard logical.cells.map({ $0! }) == indexedSolution else {
            throw PuzzleValidationError.logicalSolutionDoesNotMatchSemanticGrid
        }

        return PuzzleValidationReport(
            puzzleID: puzzle.id,
            revision: puzzle.revision,
            width: puzzle.solution.width,
            height: puzzle.solution.height,
            colorCount: puzzle.palette.count,
            semanticHash: actualHash,
            exactSolutionCount: exact.solutionCount,
            logicalSolverVersion: logical.solverVersion,
            logicalSteps: logical.steps,
            usedPrefilledCells: !puzzle.prefilledCells.isEmpty
        )
    }

    private static func validateStructure(_ puzzle: PuzzleDefinition) throws {
        guard puzzle.schema == KanakaCoreVersion.puzzleSchema else {
            throw PuzzleValidationError.unsupportedSchema(puzzle.schema)
        }
        guard !puzzle.id.isEmpty, puzzle.revision >= 1 else {
            throw PuzzleValidationError.invalidIdentity
        }
        guard puzzle.rulesVersion == KanakaCoreVersion.rules else {
            throw PuzzleValidationError.unsupportedRulesVersion(puzzle.rulesVersion)
        }
        guard puzzle.solverVersion == KanakaCoreVersion.logicalSolver else {
            throw PuzzleValidationError.unsupportedSolverVersion(puzzle.solverVersion)
        }

        let grid = puzzle.solution
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(grid.width),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(grid.height) else {
            throw PuzzleValidationError.invalidDimensions
        }
        guard grid.origin == "top-left", grid.order == "row-major" else {
            throw PuzzleValidationError.invalidGridConvention
        }
        let expectedCellCount = grid.width * grid.height
        guard grid.cells.count == expectedCellCount else {
            throw PuzzleValidationError.invalidCellCount(expected: expectedCellCount, actual: grid.cells.count)
        }

        guard !puzzle.palette.isEmpty,
              puzzle.palette.count <= KanakaCoreLimits.maximumPaletteColorCount else {
            throw PuzzleValidationError.invalidPalette(
                "color count must be in 1...\(KanakaCoreLimits.maximumPaletteColorCount)"
            )
        }
        let expectedIndices = Array(1...puzzle.palette.count)
        let actualIndices = puzzle.palette.map(\.colorIndex).sorted()
        guard actualIndices == expectedIndices else {
            throw PuzzleValidationError.invalidPalette("colorIndex values must be contiguous and 1-based")
        }
        let colorIds = puzzle.palette.map(\.colorId)
        guard Set(colorIds).count == colorIds.count,
              colorIds.allSatisfy({ !$0.isEmpty && $0 != "empty" }) else {
            throw PuzzleValidationError.invalidPalette("colorId values must be unique, non-empty, and not 'empty'")
        }
        let symbols = puzzle.palette.map(\.accessibilitySymbol)
        guard Set(symbols).count == symbols.count, symbols.allSatisfy({ !$0.isEmpty }) else {
            throw PuzzleValidationError.invalidPalette("accessibility symbols must be unique and non-empty")
        }
        guard puzzle.palette.allSatisfy({ color in
            (0...255).contains(color.sRGB8.r)
                && (0...255).contains(color.sRGB8.g)
                && (0...255).contains(color.sRGB8.b)
        }) else {
            throw PuzzleValidationError.invalidPalette("sRGB8 channels must be in 0...255")
        }
        guard grid.cells.allSatisfy({ $0.map(Set(colorIds).contains) ?? true }) else {
            throw PuzzleValidationError.invalidPalette("solution references an unknown colorId")
        }

        guard puzzle.clues.rows.count == grid.height,
              puzzle.clues.columns.count == grid.width else {
            throw PuzzleValidationError.invalidClue("row/column counts must match board dimensions")
        }
        let validColorIndices = Set(actualIndices)
        let allClues = puzzle.clues.rows.flatMap { $0 } + puzzle.clues.columns.flatMap { $0 }
        guard allClues.allSatisfy({ $0.count > 0 && validColorIndices.contains($0.colorIndex) }) else {
            throw PuzzleValidationError.invalidClue("counts must be positive and colorIndex values must exist")
        }

        if puzzle.kind == .formal, !puzzle.prefilledCells.isEmpty {
            throw PuzzleValidationError.formalPuzzleContainsPrefilledCells
        }
        var occupiedCoordinates = Set<String>()
        for cell in puzzle.prefilledCells {
            guard (0..<grid.width).contains(cell.x), (0..<grid.height).contains(cell.y) else {
                throw PuzzleValidationError.invalidPrefilledCell("coordinate is outside the board")
            }
            let coordinate = "\(cell.x),\(cell.y)"
            guard occupiedCoordinates.insert(coordinate).inserted else {
                throw PuzzleValidationError.invalidPrefilledCell("duplicate coordinate \(coordinate)")
            }
            let solutionColor = grid.cells[cell.y * grid.width + cell.x]
            switch cell.state {
            case .excluded:
                guard cell.colorId == nil, solutionColor == nil else {
                    throw PuzzleValidationError.invalidPrefilledCell("excluded state must match an empty solution cell and omit colorId")
                }
            case .filled:
                guard let colorId = cell.colorId,
                      Set(colorIds).contains(colorId),
                      solutionColor == colorId else {
                    throw PuzzleValidationError.invalidPrefilledCell("filled state must match the solution colorId")
                }
            }
        }
    }
}
