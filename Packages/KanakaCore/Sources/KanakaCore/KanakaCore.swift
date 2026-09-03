/// Stable version identifiers shared by the app and content compiler.
public enum KanakaCoreVersion {
    public static let puzzleSchema = "puzzle-definition-v1"
    public static let rules = "colored-nonogram-v1"
    public static let logicalSolver = "line-candidate-intersection-v1"
}

public enum KanakaCoreLimits {
    public static let maximumBoardDimension = 25
    public static let maximumPaletteColorCount = 254
}
