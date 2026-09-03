public enum RuntimeContentSchema {
    public static let museum = "museum-v1"
    public static let gallery = "gallery-v1"
    public static let artwork = "artwork-v1"
    public static let repairFragment = "repair-fragment-v1"
}

public struct MuseumDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let id: String
    public let revision: Int
    public let galleryIDs: [String]

    public init(schema: String, id: String, revision: Int, galleryIDs: [String]) {
        self.schema = schema
        self.id = id
        self.revision = revision
        self.galleryIDs = galleryIDs
    }
}

public struct GalleryDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let id: String
    public let revision: Int
    public let museumID: String
    public let chapterNarrativeID: String
    public let artworkIDs: [String]

    public init(
        schema: String,
        id: String,
        revision: Int,
        museumID: String,
        chapterNarrativeID: String,
        artworkIDs: [String]
    ) {
        self.schema = schema
        self.id = id
        self.revision = revision
        self.museumID = museumID
        self.chapterNarrativeID = chapterNarrativeID
        self.artworkIDs = artworkIDs
    }
}

public struct ArtworkDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let id: String
    public let revision: Int
    public let museumID: String
    public let galleryID: String
    public let repairFragmentIDs: [String]
    public let blueprintID: String

    public init(
        schema: String,
        id: String,
        revision: Int,
        museumID: String,
        galleryID: String,
        repairFragmentIDs: [String],
        blueprintID: String
    ) {
        self.schema = schema
        self.id = id
        self.revision = revision
        self.museumID = museumID
        self.galleryID = galleryID
        self.repairFragmentIDs = repairFragmentIDs
        self.blueprintID = blueprintID
    }
}

public struct RepairFragmentDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let id: String
    public let revision: Int
    public let artworkID: String
    public let region: NormalizedRegion
    public let puzzleDefinitionID: String

    public init(
        schema: String,
        id: String,
        revision: Int,
        artworkID: String,
        region: NormalizedRegion,
        puzzleDefinitionID: String
    ) {
        self.schema = schema
        self.id = id
        self.revision = revision
        self.artworkID = artworkID
        self.region = region
        self.puzzleDefinitionID = puzzleDefinitionID
    }
}

public struct NormalizedRegion: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite
            && x >= 0 && y >= 0
            && width > 0 && height > 0
            && x + width <= 1
            && y + height <= 1
    }
}
