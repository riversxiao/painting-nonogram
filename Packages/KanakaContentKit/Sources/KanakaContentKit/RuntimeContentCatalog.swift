import Foundation
import KanakaCore

public struct CurrentFragmentIdentity: Equatable, Hashable, Sendable {
    public let fragmentID: String
    public let puzzleID: String
    public let puzzleRevision: Int
    public let puzzleSemanticHash: String
}

public struct FragmentContentContext: Sendable {
    public let fragment: RepairFragmentDefinition
    public let artwork: ArtworkDefinition
    public let puzzle: PuzzleDefinition
}

public enum RuntimeContentCatalogError: Error, Equatable, CustomStringConvertible {
    case duplicate(kind: String, id: String)
    case missing(kind: String, id: String)
    case inconsistent(String)
    case unreadable(String)

    public var description: String {
        switch self {
        case .duplicate(let kind, let id): "Duplicate \(kind) ID: \(id)"
        case .missing(let kind, let id): "Missing \(kind): \(id)"
        case .inconsistent(let reason): "Inconsistent runtime content: \(reason)"
        case .unreadable(let reason): "Unreadable runtime content: \(reason)"
        }
    }
}

public struct ProductionAssetCounts: Equatable, Sendable {
    public let beadPatterns: Int
    public let blueprints: Int
}

public struct ActiveProductionRevisions: Equatable, Sendable {
    public let beadPatterns: [String: Int]
    public let blueprints: [String: Int]
}

private struct BeadRevisionIdentity: Hashable {
    let assetID: String
    let revision: Int
}

private struct BlueprintRevisionIdentity: Hashable {
    let blueprintID: String
    let revision: Int
}

public struct RuntimeContentCatalog: Sendable {
    public let museums: [String: MuseumDefinition]
    public let galleries: [String: GalleryDefinition]
    public let artworks: [String: ArtworkDefinition]
    public let fragments: [String: RepairFragmentDefinition]
    public let puzzles: [String: PuzzleDefinition]
    public let experience: PlayableExperienceDefinition
    private let beadPatterns: [String: BeadPatternDefinition]
    private let blueprints: [String: BlueprintDefinition]

    public var productionAssetCounts: ProductionAssetCounts {
        ProductionAssetCounts(beadPatterns: beadPatterns.count, blueprints: blueprints.count)
    }

    public var activeProductionRevisions: ActiveProductionRevisions {
        ActiveProductionRevisions(
            beadPatterns: beadPatterns.mapValues(\.revision),
            blueprints: blueprints.mapValues(\.revision)
        )
    }

    public static func loadValidated(directoryURL: URL) throws -> RuntimeContentCatalog {
        _ = try ContentBundleValidator.validate(directoryURL: directoryURL)
        let files = try discoverFiles(directoryURL)
        let museums = try decode(files["museum.json", default: []], as: MuseumDefinition.self)
        let galleries = try decode(files["gallery.json", default: []], as: GalleryDefinition.self)
        let artworks = try decode(files["artwork.json", default: []], as: ArtworkDefinition.self)
        let fragments = try decode(files["fragment.json", default: []], as: RepairFragmentDefinition.self)
        let puzzles = try decode(files["puzzle-definition.json", default: []], as: PuzzleDefinition.self)

        let manifestURLs = files["production-assets.json", default: []]
        guard manifestURLs.count == 1 else {
            throw RuntimeContentCatalogError.inconsistent(
                "exactly one production-assets.json manifest is required"
            )
        }
        let manifest = try decode(manifestURLs, as: ProductionAssetManifest.self)[0]
        guard manifest.schema == ProductionContentSchema.assetManifest else {
            throw RuntimeContentCatalogError.inconsistent(
                "unsupported production asset manifest schema \(manifest.schema)"
            )
        }

        let allBeadPatterns = try files["bead-pattern.json", default: []]
            .sorted(by: { $0.path < $1.path })
            .map { url in
                try ProductionContentValidator.decodeAndValidateBeadPattern(
                    data: Data(contentsOf: url)
                )
            }
        let beadByRevision = try unique(
            allBeadPatterns,
            kind: "BeadPattern revision"
        ) { BeadRevisionIdentity(assetID: $0.assetID, revision: $0.revision) }
        try validateRevisionSets(
            allBeadPatterns.map { ($0.assetID, $0.revision) },
            kind: "BeadPattern"
        )
        let activeBeadPatterns = try resolveActiveBeads(
            manifest.activeBeadAssets,
            all: beadByRevision,
            knownAssetIDs: Set(allBeadPatterns.map(\.assetID))
        )

        let allBlueprints = try files["blueprint.json", default: []]
            .sorted(by: { $0.path < $1.path })
            .map { url -> BlueprintDefinition in
                let data = try Data(contentsOf: url)
                let undecorated = try JSONDecoder().decode(BlueprintDefinition.self, from: data)
                let sourceIdentity = BeadRevisionIdentity(
                    assetID: undecorated.sourceBeadAsset.assetID,
                    revision: undecorated.sourceBeadAsset.revision
                )
                guard let source = beadByRevision[sourceIdentity],
                      source.contentHash == undecorated.sourceBeadAsset.contentHash else {
                    throw RuntimeContentCatalogError.missing(
                        kind: "BeadPattern revision",
                        id: "\(undecorated.sourceBeadAsset.assetID)@\(undecorated.sourceBeadAsset.revision)"
                    )
                }
                return try ProductionContentValidator.decodeAndValidateBlueprint(
                    data: data,
                    source: source
                )
            }
        let blueprintByRevision = try unique(
            allBlueprints,
            kind: "Blueprint revision"
        ) { BlueprintRevisionIdentity(blueprintID: $0.blueprintID, revision: $0.revision) }
        try validateRevisionSets(
            allBlueprints.map { ($0.blueprintID, $0.revision) },
            kind: "Blueprint"
        )
        let activeBlueprints = try resolveActiveBlueprints(
            manifest.activeBlueprints,
            all: blueprintByRevision,
            knownBlueprintIDs: Set(allBlueprints.map(\.blueprintID))
        )

        let museumMap = try unique(museums, kind: "Museum", id: \.id)
        let galleryMap = try unique(galleries, kind: "Gallery", id: \.id)
        let artworkMap = try unique(artworks, kind: "Artwork", id: \.id)
        let fragmentMap = try unique(fragments, kind: "Fragment", id: \.id)
        let puzzleMap = try unique(puzzles, kind: "Puzzle", id: \.id)

        let experienceURLs = files["playable-experience.json", default: []]
        guard experienceURLs.count == 1 else {
            throw RuntimeContentCatalogError.inconsistent(
                "exactly one playable-experience.json definition is required"
            )
        }
        let experience = try decode(
            experienceURLs,
            as: PlayableExperienceDefinition.self
        )[0]
        try PlayableExperienceValidator.validate(
            experience,
            museumIDs: Set(museumMap.keys),
            galleryIDs: Set(galleryMap.keys),
            artworkIDs: Set(artworkMap.keys),
            fragmentIDs: Set(fragmentMap.keys),
            puzzles: puzzleMap
        )

        for blueprint in activeBlueprints.values {
            guard let activeSource = activeBeadPatterns[blueprint.sourceBeadAsset.assetID],
                  activeSource.revision == blueprint.sourceBeadAsset.revision,
                  activeSource.contentHash == blueprint.sourceBeadAsset.contentHash else {
                throw RuntimeContentCatalogError.inconsistent(
                    "active Blueprint \(blueprint.blueprintID) does not use its source asset's active revision"
                )
            }
        }

        var referencedBlueprintIDs = Set<String>()
        for artwork in artworks {
            guard let blueprint = activeBlueprints[artwork.blueprintID] else {
                throw RuntimeContentCatalogError.missing(kind: "active Blueprint", id: artwork.blueprintID)
            }
            guard blueprint.artworkID == artwork.id else {
                throw RuntimeContentCatalogError.inconsistent(
                    "Blueprint \(blueprint.blueprintID) belongs to \(blueprint.artworkID), expected \(artwork.id)"
                )
            }
            guard referencedBlueprintIDs.insert(blueprint.blueprintID).inserted else {
                throw RuntimeContentCatalogError.inconsistent("Blueprint \(blueprint.blueprintID) is shared")
            }
        }
        guard referencedBlueprintIDs.count == activeBlueprints.count else {
            throw RuntimeContentCatalogError.inconsistent("orphan active Blueprint detected")
        }

        return RuntimeContentCatalog(
            museums: museumMap,
            galleries: galleryMap,
            artworks: artworkMap,
            fragments: fragmentMap,
            puzzles: puzzleMap,
            experience: experience,
            beadPatterns: activeBeadPatterns,
            blueprints: activeBlueprints
        )
    }

    public func fragmentContext(id: String) throws -> FragmentContentContext {
        guard let fragment = fragments[id] else {
            throw RuntimeContentCatalogError.missing(kind: "Fragment", id: id)
        }
        guard let artwork = artworks[fragment.artworkID] else {
            throw RuntimeContentCatalogError.missing(kind: "Artwork", id: fragment.artworkID)
        }
        guard let puzzle = puzzles[fragment.puzzleDefinitionID] else {
            throw RuntimeContentCatalogError.missing(kind: "Puzzle", id: fragment.puzzleDefinitionID)
        }
        return FragmentContentContext(fragment: fragment, artwork: artwork, puzzle: puzzle)
    }

    public func currentFragmentIdentities(artworkID: String) throws -> [CurrentFragmentIdentity] {
        guard let artwork = artworks[artworkID] else {
            throw RuntimeContentCatalogError.missing(kind: "Artwork", id: artworkID)
        }
        return try artwork.repairFragmentIDs.map { fragmentID in
            let context = try fragmentContext(id: fragmentID)
            return CurrentFragmentIdentity(
                fragmentID: fragmentID,
                puzzleID: context.puzzle.id,
                puzzleRevision: context.puzzle.revision,
                puzzleSemanticHash: context.puzzle.semanticHash
            )
        }
    }

    @_spi(KanakaProductDomain)
    public func blueprintPayload(forArtworkID artworkID: String) throws -> BlueprintDefinition {
        guard let artwork = artworks[artworkID] else {
            throw RuntimeContentCatalogError.missing(kind: "Artwork", id: artworkID)
        }
        guard let blueprint = blueprints[artwork.blueprintID] else {
            throw RuntimeContentCatalogError.missing(kind: "Blueprint", id: artwork.blueprintID)
        }
        return blueprint
    }

    private static func resolveActiveBeads(
        _ references: [BeadAssetReference],
        all: [BeadRevisionIdentity: BeadPatternDefinition],
        knownAssetIDs: Set<String>
    ) throws -> [String: BeadPatternDefinition] {
        var active: [String: BeadPatternDefinition] = [:]
        for reference in references {
            guard active[reference.assetID] == nil else {
                throw RuntimeContentCatalogError.duplicate(kind: "active BeadPattern", id: reference.assetID)
            }
            let identity = BeadRevisionIdentity(assetID: reference.assetID, revision: reference.revision)
            guard let pattern = all[identity], pattern.contentHash == reference.contentHash else {
                throw RuntimeContentCatalogError.missing(
                    kind: "active BeadPattern revision",
                    id: "\(reference.assetID)@\(reference.revision)"
                )
            }
            active[reference.assetID] = pattern
        }
        guard Set(active.keys) == knownAssetIDs else {
            throw RuntimeContentCatalogError.inconsistent(
                "production manifest must select exactly one active revision for every bead asset ID"
            )
        }
        return active
    }

    private static func resolveActiveBlueprints(
        _ references: [BlueprintAssetReference],
        all: [BlueprintRevisionIdentity: BlueprintDefinition],
        knownBlueprintIDs: Set<String>
    ) throws -> [String: BlueprintDefinition] {
        var active: [String: BlueprintDefinition] = [:]
        for reference in references {
            guard active[reference.blueprintID] == nil else {
                throw RuntimeContentCatalogError.duplicate(kind: "active Blueprint", id: reference.blueprintID)
            }
            let identity = BlueprintRevisionIdentity(
                blueprintID: reference.blueprintID,
                revision: reference.revision
            )
            guard let blueprint = all[identity], blueprint.blueprintHash == reference.blueprintHash else {
                throw RuntimeContentCatalogError.missing(
                    kind: "active Blueprint revision",
                    id: "\(reference.blueprintID)@\(reference.revision)"
                )
            }
            active[reference.blueprintID] = blueprint
        }
        guard Set(active.keys) == knownBlueprintIDs else {
            throw RuntimeContentCatalogError.inconsistent(
                "production manifest must select exactly one active revision for every Blueprint ID"
            )
        }
        return active
    }

    private static func validateRevisionSets(
        _ values: [(id: String, revision: Int)],
        kind: String
    ) throws {
        var revisionsByID: [String: [Int]] = [:]
        for value in values {
            revisionsByID[value.id, default: []].append(value.revision)
        }
        for (id, revisions) in revisionsByID {
            let ordered = revisions.sorted()
            guard ordered.allSatisfy({ $0 > 0 }),
                  zip(ordered, ordered.dropFirst()).allSatisfy({ $0 < $1 }) else {
                throw RuntimeContentCatalogError.inconsistent(
                    "\(kind) \(id) revisions must be positive and strictly increasing"
                )
            }
        }
    }

    private static func discoverFiles(_ root: URL) throws -> [String: [URL]] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeContentCatalogError.unreadable(root.path)
        }
        let accepted = Set([
            "museum.json", "gallery.json", "artwork.json", "fragment.json",
            "puzzle-definition.json", "bead-pattern.json", "blueprint.json",
            "production-assets.json", "playable-experience.json",
        ])
        var result: [String: [URL]] = [:]
        for case let url as URL in enumerator where accepted.contains(url.lastPathComponent) {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[url.lastPathComponent, default: []].append(url)
            }
        }
        return result
    }

    private static func decode<T: Decodable>(_ urls: [URL], as type: T.Type) throws -> [T] {
        try urls.sorted(by: { $0.path < $1.path }).map { url in
            do { return try JSONDecoder().decode(T.self, from: Data(contentsOf: url)) }
            catch { throw RuntimeContentCatalogError.unreadable("\(url.path): \(error)") }
        }
    }

    private static func unique<T, ID: Hashable>(
        _ values: [T],
        kind: String,
        id: KeyPath<T, ID>
    ) throws -> [ID: T] {
        try unique(values, kind: kind) { $0[keyPath: id] }
    }

    private static func unique<T, ID: Hashable>(
        _ values: [T],
        kind: String,
        id: (T) -> ID
    ) throws -> [ID: T] {
        var result: [ID: T] = [:]
        for value in values {
            let key = id(value)
            guard result.updateValue(value, forKey: key) == nil else {
                throw RuntimeContentCatalogError.duplicate(kind: kind, id: String(describing: key))
            }
        }
        return result
    }
}
