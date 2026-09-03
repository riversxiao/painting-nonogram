public struct PuzzleDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let id: String
    public let revision: Int
    public let kind: PuzzleKind
    public let rulesVersion: String
    public let solverVersion: String
    public let palette: [PuzzleColor]
    public let solution: SemanticGrid
    public let clues: PuzzleClues
    public let prefilledCells: [PrefilledCell]
    public let semanticHash: String

    public init(
        schema: String,
        id: String,
        revision: Int,
        kind: PuzzleKind,
        rulesVersion: String,
        solverVersion: String,
        palette: [PuzzleColor],
        solution: SemanticGrid,
        clues: PuzzleClues,
        prefilledCells: [PrefilledCell],
        semanticHash: String
    ) {
        self.schema = schema
        self.id = id
        self.revision = revision
        self.kind = kind
        self.rulesVersion = rulesVersion
        self.solverVersion = solverVersion
        self.palette = palette
        self.solution = solution
        self.clues = clues
        self.prefilledCells = prefilledCells
        self.semanticHash = semanticHash
    }
}

public enum PuzzleKind: String, Codable, Sendable {
    case formal
    case tutorial
    case demonstration
    case accessibility
}

public struct PuzzleColor: Codable, Equatable, Sendable {
    public let colorIndex: Int
    public let colorId: String
    public let sRGB8: SRGB8
    public let accessibilitySymbol: String

    public init(colorIndex: Int, colorId: String, sRGB8: SRGB8, accessibilitySymbol: String) {
        self.colorIndex = colorIndex
        self.colorId = colorId
        self.sRGB8 = sRGB8
        self.accessibilitySymbol = accessibilitySymbol
    }
}

public struct SRGB8: Codable, Equatable, Sendable {
    public let r: Int
    public let g: Int
    public let b: Int

    public init(r: Int, g: Int, b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct SemanticGrid: Codable, Equatable, Sendable {
    public let origin: String
    public let order: String
    public let width: Int
    public let height: Int
    /// `null` is empty; a string is a stable semantic `colorId`.
    public let cells: [String?]

    public init(origin: String, order: String, width: Int, height: Int, cells: [String?]) {
        self.origin = origin
        self.order = order
        self.width = width
        self.height = height
        self.cells = cells
    }
}

public struct PuzzleClues: Codable, Equatable, Sendable {
    public let rows: [[LineClue]]
    public let columns: [[LineClue]]

    public init(rows: [[LineClue]], columns: [[LineClue]]) {
        self.rows = rows
        self.columns = columns
    }
}

public struct LineClue: Codable, Equatable, Hashable, Sendable {
    public let count: Int
    public let colorIndex: Int

    public init(count: Int, colorIndex: Int) {
        self.count = count
        self.colorIndex = colorIndex
    }
}

public struct PrefilledCell: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let state: PrefilledCellState
    public let colorId: String?

    public init(x: Int, y: Int, state: PrefilledCellState, colorId: String? = nil) {
        self.x = x
        self.y = y
        self.state = state
        self.colorId = colorId
    }
}

public enum PrefilledCellState: String, Codable, Sendable {
    case excluded
    case filled
}

public enum PuzzleModelError: Error, Equatable, CustomStringConvertible {
    case invalidGridDimensions(width: Int, height: Int)
    case unknownColorId(String)
    case invalidPrefilledColor(x: Int, y: Int)

    public var description: String {
        switch self {
        case .invalidGridDimensions(let width, let height):
            return "Grid dimensions \(width)×\(height) are outside the supported range"
        case .unknownColorId(let colorId):
            return "Unknown semantic colorId: \(colorId)"
        case .invalidPrefilledColor(let x, let y):
            return "Filled prefilled cell at (\(x), \(y)) must provide a colorId"
        }
    }
}

public extension PuzzleDefinition {
    func indexedSolution() throws -> [Int] {
        let indicesByColorId = Dictionary(uniqueKeysWithValues: palette.map { ($0.colorId, $0.colorIndex) })
        return try solution.cells.map { colorId in
            guard let colorId else { return 0 }
            guard let colorIndex = indicesByColorId[colorId] else {
                throw PuzzleModelError.unknownColorId(colorId)
            }
            return colorIndex
        }
    }

    func indexedPrefilledCells() throws -> [Int?] {
        guard (1...KanakaCoreLimits.maximumBoardDimension).contains(solution.width),
              (1...KanakaCoreLimits.maximumBoardDimension).contains(solution.height) else {
            throw PuzzleModelError.invalidGridDimensions(
                width: solution.width,
                height: solution.height
            )
        }
        let indicesByColorId = Dictionary(uniqueKeysWithValues: palette.map { ($0.colorId, $0.colorIndex) })
        var cells = Array<Int?>(repeating: nil, count: solution.width * solution.height)

        for prefilled in prefilledCells {
            let offset = prefilled.y * solution.width + prefilled.x
            switch prefilled.state {
            case .excluded:
                cells[offset] = 0
            case .filled:
                guard let colorId = prefilled.colorId else {
                    throw PuzzleModelError.invalidPrefilledColor(x: prefilled.x, y: prefilled.y)
                }
                guard let colorIndex = indicesByColorId[colorId] else {
                    throw PuzzleModelError.unknownColorId(colorId)
                }
                cells[offset] = colorIndex
            }
        }
        return cells
    }
}
