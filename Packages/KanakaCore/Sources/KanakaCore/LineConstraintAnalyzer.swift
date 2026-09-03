struct LineConstraintAnalysis {
    let isFeasible: Bool
    let possibleValues: [Set<Int>]
}

private struct LineAutomatonState: Hashable {
    let clueIndex: Int
    /// Number of cells already placed in the current clue; zero means between clues.
    let runProgress: Int
    /// True after a completed clue when the next clue has the same color.
    let requiresSeparator: Bool
}

enum LineConstraintAnalyzer {
    static func analyze(
        length: Int,
        clues: [LineClue],
        knownCells: [Int?]
    ) -> LineConstraintAnalysis {
        guard length >= 0,
              knownCells.count == length,
              clues.allSatisfy({ $0.count > 0 && $0.colorIndex > 0 }) else {
            return LineConstraintAnalysis(isFeasible: false, possibleValues: [])
        }

        let domain = [0] + Array(Set(clues.map(\.colorIndex))).sorted()
        let initial = LineAutomatonState(clueIndex: 0, runProgress: 0, requiresSeparator: false)
        var forward = Array(repeating: Set<LineAutomatonState>(), count: length + 1)
        forward[0].insert(initial)

        for position in 0..<length {
            let values = knownCells[position].map { [$0] } ?? domain
            for state in forward[position] {
                for value in values {
                    if let next = transition(from: state, value: value, clues: clues) {
                        forward[position + 1].insert(next)
                    }
                }
            }
        }

        var viable = Array(repeating: Set<LineAutomatonState>(), count: length + 1)
        viable[length] = Set(forward[length].filter { isAccepting($0, clueCount: clues.count) })
        guard !viable[length].isEmpty else {
            return LineConstraintAnalysis(
                isFeasible: false,
                possibleValues: Array(repeating: [], count: length)
            )
        }

        if length > 0 {
            for position in stride(from: length - 1, through: 0, by: -1) {
                let values = knownCells[position].map { [$0] } ?? domain
                for state in forward[position] {
                    if values.contains(where: { value in
                        transition(from: state, value: value, clues: clues)
                            .map(viable[position + 1].contains) ?? false
                    }) {
                        viable[position].insert(state)
                    }
                }
            }
        }

        guard viable[0].contains(initial) else {
            return LineConstraintAnalysis(
                isFeasible: false,
                possibleValues: Array(repeating: [], count: length)
            )
        }

        var possibleValues = Array(repeating: Set<Int>(), count: length)
        for position in 0..<length {
            let values = knownCells[position].map { [$0] } ?? domain
            for state in forward[position] where viable[position].contains(state) {
                for value in values {
                    guard let next = transition(from: state, value: value, clues: clues),
                          viable[position + 1].contains(next) else { continue }
                    possibleValues[position].insert(value)
                }
            }
        }

        return LineConstraintAnalysis(isFeasible: true, possibleValues: possibleValues)
    }

    private static func transition(
        from state: LineAutomatonState,
        value: Int,
        clues: [LineClue]
    ) -> LineAutomatonState? {
        if state.runProgress > 0 {
            guard state.clueIndex < clues.count else { return nil }
            let clue = clues[state.clueIndex]
            guard value == clue.colorIndex else { return nil }
            let progress = state.runProgress + 1
            if progress == clue.count {
                return completedState(after: state.clueIndex, clues: clues)
            }
            return progress < clue.count
                ? LineAutomatonState(
                    clueIndex: state.clueIndex,
                    runProgress: progress,
                    requiresSeparator: false
                )
                : nil
        }

        if value == 0 {
            return LineAutomatonState(
                clueIndex: state.clueIndex,
                runProgress: 0,
                requiresSeparator: false
            )
        }

        guard !state.requiresSeparator,
              state.clueIndex < clues.count else { return nil }
        let clue = clues[state.clueIndex]
        guard value == clue.colorIndex else { return nil }
        if clue.count == 1 {
            return completedState(after: state.clueIndex, clues: clues)
        }
        return LineAutomatonState(
            clueIndex: state.clueIndex,
            runProgress: 1,
            requiresSeparator: false
        )
    }

    private static func completedState(
        after clueIndex: Int,
        clues: [LineClue]
    ) -> LineAutomatonState {
        let nextIndex = clueIndex + 1
        let requiresSeparator = nextIndex < clues.count
            && clues[clueIndex].colorIndex == clues[nextIndex].colorIndex
        return LineAutomatonState(
            clueIndex: nextIndex,
            runProgress: 0,
            requiresSeparator: requiresSeparator
        )
    }

    private static func isAccepting(_ state: LineAutomatonState, clueCount: Int) -> Bool {
        state.clueIndex == clueCount && state.runProgress == 0
    }
}
