public struct ExactSolutionResult: Equatable, Sendable {
    public let solutionCount: Int
    public let firstSolution: [Int]?

    public var hasUniqueSolution: Bool { solutionCount == 1 }

    public init(solutionCount: Int, firstSolution: [Int]?) {
        self.solutionCount = solutionCount
        self.firstSolution = firstSolution
    }
}

public enum ExactColoredNonogramSolver {
    /// Counts up to `solutionLimit`; a result equal to the limit means "at least this many".
    public static func solve(
        width: Int,
        height: Int,
        clues: PuzzleClues,
        initialCells: [Int?]? = nil,
        solutionLimit: Int = 2
    ) -> ExactSolutionResult {
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(width),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(height),
              solutionLimit > 0,
              clues.rows.count == height,
              clues.columns.count == width else {
            return ExactSolutionResult(solutionCount: 0, firstSolution: nil)
        }

        let cellCount = width * height
        let initial = initialCells ?? Array(repeating: nil, count: cellCount)
        guard initial.count == cellCount else {
            return ExactSolutionResult(solutionCount: 0, firstSolution: nil)
        }

        var solutionCount = 0
        var firstSolution: [Int]?

        func propagate(_ input: [Int?]) -> (cells: [Int?], domains: [Set<Int>])? {
            var cells = input

            while true {
                var domains = Array(repeating: Set<Int>(), count: cellCount)
                var rowPossibilities = Array(repeating: [Set<Int>](), count: height)
                var columnPossibilities = Array(repeating: [Set<Int>](), count: width)

                for y in 0..<height {
                    let known = (0..<width).map { cells[y * width + $0] }
                    let analysis = LineConstraintAnalyzer.analyze(
                        length: width,
                        clues: clues.rows[y],
                        knownCells: known
                    )
                    guard analysis.isFeasible else { return nil }
                    rowPossibilities[y] = analysis.possibleValues
                }

                for x in 0..<width {
                    let known = (0..<height).map { cells[$0 * width + x] }
                    let analysis = LineConstraintAnalyzer.analyze(
                        length: height,
                        clues: clues.columns[x],
                        knownCells: known
                    )
                    guard analysis.isFeasible else { return nil }
                    columnPossibilities[x] = analysis.possibleValues
                }

                var changed = false
                for y in 0..<height {
                    for x in 0..<width {
                        let offset = y * width + x
                        let possible = rowPossibilities[y][x]
                            .intersection(columnPossibilities[x][y])
                        guard !possible.isEmpty else { return nil }
                        domains[offset] = possible
                        if cells[offset] == nil, possible.count == 1 {
                            cells[offset] = possible.first!
                            changed = true
                        }
                    }
                }

                if !changed {
                    return (cells, domains)
                }
            }
        }

        func search(_ cells: [Int?]) {
            guard solutionCount < solutionLimit,
                  let propagated = propagate(cells) else { return }

            if propagated.cells.allSatisfy({ $0 != nil }) {
                let solution = propagated.cells.map { $0! }
                solutionCount += 1
                if firstSolution == nil { firstSolution = solution }
                return
            }

            let branch = propagated.cells.indices
                .filter { propagated.cells[$0] == nil }
                .min { lhs, rhs in
                    propagated.domains[lhs].count < propagated.domains[rhs].count
                }!

            for value in propagated.domains[branch].sorted() {
                var next = propagated.cells
                next[branch] = value
                search(next)
                if solutionCount >= solutionLimit { return }
            }
        }

        search(initial)
        return ExactSolutionResult(solutionCount: solutionCount, firstSolution: firstSolution)
    }
}
