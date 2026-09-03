import Foundation
import KanakaCore

public struct ContentBundleValidationReport: Sendable {
    public let museumCount: Int
    public let galleryCount: Int
    public let artworkCount: Int
    public let repairFragmentCount: Int
    public let puzzleCount: Int
    public let artworkCardinalityCounts: [Int: Int]
    public let puzzleReports: [PuzzleValidationReport]

    public var formattedDescription: String {
        let cardinalities = (1...4)
            .map { "\($0):\(artworkCardinalityCounts[$0, default: 0])" }
            .joined(separator: ", ")
        return [
            "✓ runtime content relationships",
            "  museums: \(museumCount), galleries: \(galleryCount)",
            "  artworks: \(artworkCount), fragments: \(repairFragmentCount)",
            "  puzzles: \(puzzleCount)",
            "  artwork fragment cardinalities: \(cardinalities)",
        ].joined(separator: "\n")
    }
}

public enum ContentBundleValidationError: Error, CustomStringConvertible {
    case invalidDirectory(String)
    case missingEntityType(String)
    case decodeFailed(path: String, reason: String)
    case invalidEntity(kind: String, id: String, reason: String)
    case duplicateID(kind: String, id: String)
    case duplicateReference(owner: String, id: String)
    case danglingReference(owner: String, kind: String, id: String)
    case inconsistentReference(String)
    case orphanEntity(kind: String, id: String)
    case sharedPuzzleDefinition(id: String, fragmentIDs: [String])

    public var description: String {
        switch self {
        case .invalidDirectory(let path):
            return "Not a readable content directory: \(path)"
        case .missingEntityType(let kind):
            return "Content bundle contains no \(kind) definitions"
        case .decodeFailed(let path, let reason):
            return "Could not decode \(path): \(reason)"
        case .invalidEntity(let kind, let id, let reason):
            return "Invalid \(kind) '\(id)': \(reason)"
        case .duplicateID(let kind, let id):
            return "Duplicate \(kind) id: \(id)"
        case .duplicateReference(let owner, let id):
            return "\(owner) contains duplicate reference: \(id)"
        case .danglingReference(let owner, let kind, let id):
            return "\(owner) references missing \(kind): \(id)"
        case .inconsistentReference(let reason):
            return "Inconsistent content relationship: \(reason)"
        case .orphanEntity(let kind, let id):
            return "Unreferenced \(kind): \(id)"
        case .sharedPuzzleDefinition(let id, let fragmentIDs):
            return "PuzzleDefinition \(id) is shared by fragments: \(fragmentIDs.sorted().joined(separator: ", "))"
        }
    }
}

public enum ContentBundleValidator {
    public static func validate(directoryURL: URL) throws -> ContentBundleValidationReport {
        let files = try discoverFiles(in: directoryURL)
        let decoder = JSONDecoder()

        let museums: [MuseumDefinition] = try decode(files.museums, as: MuseumDefinition.self, decoder: decoder)
        let galleries: [GalleryDefinition] = try decode(files.galleries, as: GalleryDefinition.self, decoder: decoder)
        let artworks: [ArtworkDefinition] = try decode(files.artworks, as: ArtworkDefinition.self, decoder: decoder)
        let fragments: [RepairFragmentDefinition] = try decode(
            files.fragments,
            as: RepairFragmentDefinition.self,
            decoder: decoder
        )
        let puzzles: [PuzzleDefinition] = try decode(files.puzzles, as: PuzzleDefinition.self, decoder: decoder)

        guard !museums.isEmpty else { throw ContentBundleValidationError.missingEntityType("Museum") }
        guard !galleries.isEmpty else { throw ContentBundleValidationError.missingEntityType("Gallery") }
        guard !artworks.isEmpty else { throw ContentBundleValidationError.missingEntityType("Artwork") }
        guard !fragments.isEmpty else { throw ContentBundleValidationError.missingEntityType("RepairFragment") }
        guard !puzzles.isEmpty else { throw ContentBundleValidationError.missingEntityType("PuzzleDefinition") }

        let museumByID = try indexed(museums, kind: "Museum", id: { $0.id })
        let galleryByID = try indexed(galleries, kind: "Gallery", id: { $0.id })
        let artworkByID = try indexed(artworks, kind: "Artwork", id: { $0.id })
        let fragmentByID = try indexed(fragments, kind: "RepairFragment", id: { $0.id })
        let puzzleByID = try indexed(puzzles, kind: "PuzzleDefinition", id: { $0.id })

        try validateEntities(
            museums: museums,
            galleries: galleries,
            artworks: artworks,
            fragments: fragments
        )
        try validateRelationships(
            museumByID: museumByID,
            galleryByID: galleryByID,
            artworkByID: artworkByID,
            fragmentByID: fragmentByID,
            puzzleByID: puzzleByID
        )

        let puzzleReports = try puzzles
            .sorted { $0.id < $1.id }
            .map(PuzzleContentValidator.validate)
        let cardinalities = Dictionary(grouping: artworks, by: { $0.repairFragmentIDs.count })
            .mapValues(\.count)

        return ContentBundleValidationReport(
            museumCount: museums.count,
            galleryCount: galleries.count,
            artworkCount: artworks.count,
            repairFragmentCount: fragments.count,
            puzzleCount: puzzles.count,
            artworkCardinalityCounts: cardinalities,
            puzzleReports: puzzleReports
        )
    }

    private static func validateEntities(
        museums: [MuseumDefinition],
        galleries: [GalleryDefinition],
        artworks: [ArtworkDefinition],
        fragments: [RepairFragmentDefinition]
    ) throws {
        for museum in museums {
            try validateHeader(
                schema: museum.schema,
                expectedSchema: RuntimeContentSchema.museum,
                id: museum.id,
                revision: museum.revision,
                kind: "Museum"
            )
            guard !museum.galleryIDs.isEmpty else {
                throw ContentBundleValidationError.invalidEntity(
                    kind: "Museum", id: museum.id, reason: "galleryIDs must not be empty"
                )
            }
            try requireUnique(museum.galleryIDs, owner: "Museum \(museum.id).galleryIDs")
        }

        for gallery in galleries {
            try validateHeader(
                schema: gallery.schema,
                expectedSchema: RuntimeContentSchema.gallery,
                id: gallery.id,
                revision: gallery.revision,
                kind: "Gallery"
            )
            guard !gallery.museumID.isEmpty,
                  !gallery.chapterNarrativeID.isEmpty,
                  !gallery.artworkIDs.isEmpty else {
                throw ContentBundleValidationError.invalidEntity(
                    kind: "Gallery",
                    id: gallery.id,
                    reason: "museumID, chapterNarrativeID, and artworkIDs are required"
                )
            }
            try requireUnique(gallery.artworkIDs, owner: "Gallery \(gallery.id).artworkIDs")
        }

        for artwork in artworks {
            try validateHeader(
                schema: artwork.schema,
                expectedSchema: RuntimeContentSchema.artwork,
                id: artwork.id,
                revision: artwork.revision,
                kind: "Artwork"
            )
            guard !artwork.museumID.isEmpty,
                  !artwork.galleryID.isEmpty,
                  !artwork.blueprintID.isEmpty else {
                throw ContentBundleValidationError.invalidEntity(
                    kind: "Artwork",
                    id: artwork.id,
                    reason: "museumID, galleryID, and blueprintID are required"
                )
            }
            guard (1...4).contains(artwork.repairFragmentIDs.count) else {
                throw ContentBundleValidationError.invalidEntity(
                    kind: "Artwork",
                    id: artwork.id,
                    reason: "repairFragmentIDs count must be in 1...4"
                )
            }
            try requireUnique(
                artwork.repairFragmentIDs,
                owner: "Artwork \(artwork.id).repairFragmentIDs"
            )
        }

        for fragment in fragments {
            try validateHeader(
                schema: fragment.schema,
                expectedSchema: RuntimeContentSchema.repairFragment,
                id: fragment.id,
                revision: fragment.revision,
                kind: "RepairFragment"
            )
            guard !fragment.artworkID.isEmpty, !fragment.puzzleDefinitionID.isEmpty else {
                throw ContentBundleValidationError.invalidEntity(
                    kind: "RepairFragment",
                    id: fragment.id,
                    reason: "artworkID and puzzleDefinitionID are required"
                )
            }
            guard fragment.region.isValid else {
                throw ContentBundleValidationError.invalidEntity(
                    kind: "RepairFragment",
                    id: fragment.id,
                    reason: "region must have positive area and remain within normalized [0,1] bounds"
                )
            }
        }
    }

    private static func validateRelationships(
        museumByID: [String: MuseumDefinition],
        galleryByID: [String: GalleryDefinition],
        artworkByID: [String: ArtworkDefinition],
        fragmentByID: [String: RepairFragmentDefinition],
        puzzleByID: [String: PuzzleDefinition]
    ) throws {
        var referencedGalleryIDs = Set<String>()
        for museum in museumByID.values {
            for galleryID in museum.galleryIDs {
                guard let gallery = galleryByID[galleryID] else {
                    throw ContentBundleValidationError.danglingReference(
                        owner: "Museum \(museum.id)", kind: "Gallery", id: galleryID
                    )
                }
                guard gallery.museumID == museum.id else {
                    throw ContentBundleValidationError.inconsistentReference(
                        "Gallery \(gallery.id).museumID is \(gallery.museumID), expected \(museum.id)"
                    )
                }
                referencedGalleryIDs.insert(galleryID)
            }
        }
        for galleryID in galleryByID.keys where !referencedGalleryIDs.contains(galleryID) {
            throw ContentBundleValidationError.orphanEntity(kind: "Gallery", id: galleryID)
        }

        var referencedArtworkIDs = Set<String>()
        for gallery in galleryByID.values {
            guard museumByID[gallery.museumID] != nil else {
                throw ContentBundleValidationError.danglingReference(
                    owner: "Gallery \(gallery.id)", kind: "Museum", id: gallery.museumID
                )
            }
            for artworkID in gallery.artworkIDs {
                guard let artwork = artworkByID[artworkID] else {
                    throw ContentBundleValidationError.danglingReference(
                        owner: "Gallery \(gallery.id)", kind: "Artwork", id: artworkID
                    )
                }
                guard artwork.galleryID == gallery.id, artwork.museumID == gallery.museumID else {
                    throw ContentBundleValidationError.inconsistentReference(
                        "Artwork \(artwork.id) must match Gallery \(gallery.id) and Museum \(gallery.museumID)"
                    )
                }
                referencedArtworkIDs.insert(artworkID)
            }
        }
        for artworkID in artworkByID.keys where !referencedArtworkIDs.contains(artworkID) {
            throw ContentBundleValidationError.orphanEntity(kind: "Artwork", id: artworkID)
        }

        var referencedFragmentIDs = Set<String>()
        for artwork in artworkByID.values {
            guard galleryByID[artwork.galleryID] != nil,
                  museumByID[artwork.museumID] != nil else {
                throw ContentBundleValidationError.inconsistentReference(
                    "Artwork \(artwork.id) has a missing Gallery or Museum"
                )
            }
            for fragmentID in artwork.repairFragmentIDs {
                guard let fragment = fragmentByID[fragmentID] else {
                    throw ContentBundleValidationError.danglingReference(
                        owner: "Artwork \(artwork.id)", kind: "RepairFragment", id: fragmentID
                    )
                }
                guard fragment.artworkID == artwork.id else {
                    throw ContentBundleValidationError.inconsistentReference(
                        "RepairFragment \(fragment.id).artworkID is \(fragment.artworkID), expected \(artwork.id)"
                    )
                }
                referencedFragmentIDs.insert(fragmentID)
            }
        }
        for fragmentID in fragmentByID.keys where !referencedFragmentIDs.contains(fragmentID) {
            throw ContentBundleValidationError.orphanEntity(kind: "RepairFragment", id: fragmentID)
        }

        var fragmentIDsByPuzzleID: [String: [String]] = [:]
        for fragment in fragmentByID.values {
            guard puzzleByID[fragment.puzzleDefinitionID] != nil else {
                throw ContentBundleValidationError.danglingReference(
                    owner: "RepairFragment \(fragment.id)",
                    kind: "PuzzleDefinition",
                    id: fragment.puzzleDefinitionID
                )
            }
            fragmentIDsByPuzzleID[fragment.puzzleDefinitionID, default: []].append(fragment.id)
        }
        for puzzleID in puzzleByID.keys {
            guard let fragmentIDs = fragmentIDsByPuzzleID[puzzleID] else {
                throw ContentBundleValidationError.orphanEntity(kind: "PuzzleDefinition", id: puzzleID)
            }
            guard fragmentIDs.count == 1 else {
                throw ContentBundleValidationError.sharedPuzzleDefinition(
                    id: puzzleID,
                    fragmentIDs: fragmentIDs
                )
            }
        }
    }

    private static func validateHeader(
        schema: String,
        expectedSchema: String,
        id: String,
        revision: Int,
        kind: String
    ) throws {
        guard schema == expectedSchema else {
            throw ContentBundleValidationError.invalidEntity(
                kind: kind,
                id: id,
                reason: "schema must be \(expectedSchema), found \(schema)"
            )
        }
        guard !id.isEmpty, revision >= 1 else {
            throw ContentBundleValidationError.invalidEntity(
                kind: kind,
                id: id,
                reason: "id must be non-empty and revision must be at least 1"
            )
        }
    }

    private static func requireUnique(_ ids: [String], owner: String) throws {
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            throw ContentBundleValidationError.duplicateReference(owner: owner, id: id)
        }
    }

    private static func indexed<Value>(
        _ values: [Value],
        kind: String,
        id: (Value) -> String
    ) throws -> [String: Value] {
        var result: [String: Value] = [:]
        for value in values {
            let valueID = id(value)
            guard result[valueID] == nil else {
                throw ContentBundleValidationError.duplicateID(kind: kind, id: valueID)
            }
            result[valueID] = value
        }
        return result
    }

    private static func decode<Value: Decodable>(
        _ urls: [URL],
        as type: Value.Type,
        decoder: JSONDecoder
    ) throws -> [Value] {
        try urls.map { url in
            do {
                return try decoder.decode(type, from: Data(contentsOf: url))
            } catch {
                throw ContentBundleValidationError.decodeFailed(
                    path: url.path,
                    reason: String(describing: error)
                )
            }
        }
    }

    private static func discoverFiles(in directoryURL: URL) throws -> DiscoveredContentFiles {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            throw ContentBundleValidationError.invalidDirectory(directoryURL.path)
        }

        var files = DiscoveredContentFiles()
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            switch fileURL.lastPathComponent {
            case "museum.json": files.museums.append(fileURL)
            case "gallery.json": files.galleries.append(fileURL)
            case "artwork.json": files.artworks.append(fileURL)
            case "fragment.json": files.fragments.append(fileURL)
            case "puzzle-definition.json": files.puzzles.append(fileURL)
            default: continue
            }
        }
        files.sort()
        return files
    }
}

private struct DiscoveredContentFiles {
    var museums: [URL] = []
    var galleries: [URL] = []
    var artworks: [URL] = []
    var fragments: [URL] = []
    var puzzles: [URL] = []

    mutating func sort() {
        museums.sort { $0.path < $1.path }
        galleries.sort { $0.path < $1.path }
        artworks.sort { $0.path < $1.path }
        fragments.sort { $0.path < $1.path }
        puzzles.sort { $0.path < $1.path }
    }
}
