import Foundation

public enum CellState: Equatable, Sendable {
    case unknown
    case excluded
    case filled(colorId: String)
}

public enum CellStateCodecV1 {
    public static let version = 1
    public static let unknownByte: UInt8 = 0
    public static let excludedByte: UInt8 = 1

    public static func encode(
        _ cells: [CellState],
        palette: [PuzzleColor]
    ) throws -> Data {
        let paletteByID = try validatedPaletteByID(palette)
        return Data(try cells.map { state in
            switch state {
            case .unknown:
                return unknownByte
            case .excluded:
                return excludedByte
            case .filled(let colorId):
                guard let color = paletteByID[colorId] else {
                    throw CellStateCodecError.unknownColorId(colorId)
                }
                return UInt8(color.colorIndex + 1)
            }
        })
    }

    public static func decode(
        _ data: Data,
        expectedCellCount: Int,
        palette: [PuzzleColor]
    ) throws -> [CellState] {
        guard data.count == expectedCellCount else {
            throw CellStateCodecError.invalidCellCount(
                expected: expectedCellCount,
                actual: data.count
            )
        }
        let paletteByIndex = try validatedPaletteByIndex(palette)
        return try data.map { byte in
            switch byte {
            case unknownByte:
                return .unknown
            case excludedByte:
                return .excluded
            default:
                let colorIndex = Int(byte) - 1
                guard let color = paletteByIndex[colorIndex] else {
                    throw CellStateCodecError.invalidColorByte(byte)
                }
                return .filled(colorId: color.colorId)
            }
        }
    }

    static func validatedPaletteByID(
        _ palette: [PuzzleColor]
    ) throws -> [String: PuzzleColor] {
        let byIndex = try validatedPaletteByIndex(palette)
        return Dictionary(uniqueKeysWithValues: byIndex.values.map { ($0.colorId, $0) })
    }

    static func validatedPaletteByIndex(
        _ palette: [PuzzleColor]
    ) throws -> [Int: PuzzleColor] {
        guard !palette.isEmpty,
              palette.count <= KanakaCoreLimits.maximumPaletteColorCount else {
            throw CellStateCodecError.invalidPaletteCount(palette.count)
        }
        let sorted = palette.sorted { $0.colorIndex < $1.colorIndex }
        guard sorted.map(\.colorIndex) == Array(1...palette.count) else {
            throw CellStateCodecError.invalidPaletteIndices
        }
        let colorIDs = sorted.map(\.colorId)
        guard Set(colorIDs).count == colorIDs.count,
              colorIDs.allSatisfy({ !$0.isEmpty }) else {
            throw CellStateCodecError.invalidPaletteColorIDs
        }
        return Dictionary(uniqueKeysWithValues: sorted.map { ($0.colorIndex, $0) })
    }
}

public enum CellStateCodecError: Error, Equatable, CustomStringConvertible {
    case invalidCellCount(expected: Int, actual: Int)
    case invalidPaletteCount(Int)
    case invalidPaletteIndices
    case invalidPaletteColorIDs
    case unknownColorId(String)
    case invalidColorByte(UInt8)

    public var description: String {
        switch self {
        case .invalidCellCount(let expected, let actual):
            return "Expected \(expected) encoded cells, found \(actual)"
        case .invalidPaletteCount(let count):
            return "Palette count \(count) is outside 1...\(KanakaCoreLimits.maximumPaletteColorCount)"
        case .invalidPaletteIndices:
            return "Palette colorIndex values must be contiguous and 1-based"
        case .invalidPaletteColorIDs:
            return "Palette colorId values must be unique and non-empty"
        case .unknownColorId(let colorId):
            return "Cannot encode unknown colorId: \(colorId)"
        case .invalidColorByte(let byte):
            return "Encoded byte \(byte) does not map to the current palette"
        }
    }
}
