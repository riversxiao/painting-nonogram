public enum ClueGenerator {
    public static func generateLine(from cells: [Int]) -> [LineClue] {
        var clues: [LineClue] = []
        var currentColor = 0
        var currentCount = 0

        func appendCurrentRun() {
            guard currentColor > 0, currentCount > 0 else { return }
            clues.append(LineClue(count: currentCount, colorIndex: currentColor))
        }

        for cell in cells {
            if cell == currentColor, cell > 0 {
                currentCount += 1
            } else {
                appendCurrentRun()
                currentColor = cell
                currentCount = cell > 0 ? 1 : 0
            }
        }
        appendCurrentRun()
        return clues
    }

    public static func generate(
        width: Int,
        height: Int,
        cells: [Int]
    ) -> PuzzleClues {
        let rows = (0..<height).map { y in
            let start = y * width
            return generateLine(from: Array(cells[start..<(start + width)]))
        }

        let columns = (0..<width).map { x in
            generateLine(from: (0..<height).map { y in cells[y * width + x] })
        }

        return PuzzleClues(rows: rows, columns: columns)
    }
}
