import Foundation
import KanakaCore

public enum ProductionContentSchema {
    public static let beadPattern = "bead-pattern-v1"
    public static let blueprint = "blueprint-v1"
    public static let assetManifest = "production-assets-v1"
}

public struct BlueprintAssetReference: Codable, Equatable, Hashable, Sendable {
    public let blueprintID: String
    public let revision: Int
    public let blueprintHash: String

    public init(blueprintID: String, revision: Int, blueprintHash: String) {
        self.blueprintID = blueprintID
        self.revision = revision
        self.blueprintHash = blueprintHash
    }

    enum CodingKeys: String, CodingKey {
        case blueprintID = "blueprintId"
        case revision, blueprintHash
    }
}

public struct ProductionAssetManifest: Codable, Equatable, Sendable {
    public let schema: String
    public let activeBeadAssets: [BeadAssetReference]
    public let activeBlueprints: [BlueprintAssetReference]
}

public struct ProductionGrid: Codable, Equatable, Sendable {
    public let origin: String
    public let order: String
    public let width: Int
    public let height: Int
    /// `0` is empty; positive values are one-based palette indexes.
    public let cells: [Int]
}

public struct BrandColorReference: Codable, Equatable, Sendable {
    public let name: String
    public let code: String
    public let swatchVersion: String
}

public struct ProductionPaletteEntry: Codable, Equatable, Sendable {
    public let colorId: String
    public let name: [String: String]
    public let sRGB8: SRGB8
    public let brand: BrandColorReference
    public let accessibilitySymbol: String
}

public struct BoardLayout: Codable, Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let boardWidth: Int
    public let boardHeight: Int
}

public struct ProductionPhysicalSpecification: Codable, Equatable, Sendable {
    public let beadPitchMm: Double
    public let boardLayout: BoardLayout
}

public struct BeadGeneratorIdentity: Codable, Equatable, Sendable {
    public let name: String
    public let version: String
}

public struct BeadProvenance: Codable, Equatable, Sendable {
    public let sourceType: String
    public let sourceRef: String
    public let commercialUseCleared: Bool
}

public struct BeadPatternDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let assetID: String
    public let revision: Int
    public let title: String?
    public let grid: ProductionGrid
    public let palette: [ProductionPaletteEntry]
    public let physical: ProductionPhysicalSpecification
    public let generator: BeadGeneratorIdentity
    public let provenance: BeadProvenance
    public let contentHash: String

    enum CodingKeys: String, CodingKey {
        case schema
        case assetID = "assetId"
        case revision, title, grid, palette, physical, generator, provenance, contentHash
    }
}

public struct BeadAssetReference: Codable, Equatable, Hashable, Sendable {
    public let assetID: String
    public let revision: Int
    public let contentHash: String

    public init(assetID: String, revision: Int, contentHash: String) {
        self.assetID = assetID
        self.revision = revision
        self.contentHash = contentHash
    }

    enum CodingKeys: String, CodingKey {
        case assetID = "assetId"
        case revision, contentHash
    }
}

public struct BlueprintMaterialCount: Codable, Equatable, Sendable {
    public let colorId: String
    public let count: Int

    public init(colorId: String, count: Int) {
        self.colorId = colorId
        self.count = count
    }
}

public struct BlueprintCompletedSize: Codable, Equatable, Sendable {
    public let widthMm: Double
    public let heightMm: Double
}

public struct BlueprintExportRules: Codable, Equatable, Sendable {
    public let version: String
    public let pixelsPerCell: Int
    public let includeCoordinates: Bool
    public let includeLegend: Bool
    public let filenameVersion: String
}

public struct BlueprintDefinition: Codable, Equatable, Sendable {
    public let schema: String
    public let blueprintID: String
    public let revision: Int
    public let artworkID: String
    public let sourceBeadAsset: BeadAssetReference
    public let grid: ProductionGrid
    public let palette: [ProductionPaletteEntry]
    public let materialCounts: [BlueprintMaterialCount]
    public let totalBeads: Int
    public let physical: ProductionPhysicalSpecification
    public let completedSize: BlueprintCompletedSize
    public let exportRules: BlueprintExportRules
    public let blueprintHash: String

    enum CodingKeys: String, CodingKey {
        case schema
        case blueprintID = "blueprintId"
        case revision
        case artworkID = "artworkId"
        case sourceBeadAsset, grid, palette, materialCounts, totalBeads
        case physical, completedSize, exportRules, blueprintHash
    }
}

public struct BlueprintExportPlan: Equatable, Sendable {
    public let blueprintID: String
    public let revision: Int
    public let filename: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let materialCounts: [BlueprintMaterialCount]
    public let totalBeads: Int

    @_spi(KanakaProductDomain)
    public init(validatedBlueprint blueprint: BlueprintDefinition) throws {
        let width = blueprint.grid.width.multipliedReportingOverflow(
            by: blueprint.exportRules.pixelsPerCell
        )
        let height = blueprint.grid.height.multipliedReportingOverflow(
            by: blueprint.exportRules.pixelsPerCell
        )
        guard !width.overflow, !height.overflow else {
            throw ProductionContentValidationError.invalidField("export pixel dimensions overflow")
        }
        blueprintID = blueprint.blueprintID
        revision = blueprint.revision
        filename = "\(blueprint.blueprintID)-r\(blueprint.revision).png"
        pixelWidth = width.partialValue
        pixelHeight = height.partialValue
        materialCounts = blueprint.materialCounts
        totalBeads = blueprint.totalBeads
    }
}
