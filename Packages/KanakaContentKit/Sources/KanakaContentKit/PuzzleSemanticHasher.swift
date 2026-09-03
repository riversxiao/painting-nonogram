import Foundation
import KanakaCore

public enum PuzzleSemanticHasher {
    public static func hash(_ puzzle: PuzzleDefinition) -> String {
        "sha256:" + SHA256.hexDigest(canonicalData(puzzle))
    }

    public static func canonicalData(_ puzzle: PuzzleDefinition) -> Data {
        let palette = puzzle.palette
            .sorted { $0.colorIndex < $1.colorIndex }
            .map { color in
                CanonicalJSONValue.object([
                    "colorId": .string(color.colorId),
                    "colorIndex": .integer(color.colorIndex),
                ])
            }

        let solution = puzzle.solution.cells.map { colorId in
            colorId.map(CanonicalJSONValue.string) ?? .null
        }

        let prefilled = puzzle.prefilledCells
            .sorted { lhs, rhs in lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y }
            .map { cell in
                CanonicalJSONValue.object([
                    "colorId": cell.colorId.map(CanonicalJSONValue.string) ?? .null,
                    "state": .string(cell.state.rawValue),
                    "x": .integer(cell.x),
                    "y": .integer(cell.y),
                ])
            }

        return CanonicalJSON.data(.object([
            "height": .integer(puzzle.solution.height),
            "palette": .array(palette),
            "prefilledConstraints": .array(prefilled),
            "rulesVersion": .string(puzzle.rulesVersion),
            "schema": .string(KanakaContentKitVersion.puzzleSemanticHash),
            "solution": .array(solution),
            "width": .integer(puzzle.solution.width),
        ]))
    }
}
