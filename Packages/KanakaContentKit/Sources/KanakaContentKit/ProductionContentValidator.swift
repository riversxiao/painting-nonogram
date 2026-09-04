import Foundation

public enum ProductionContentValidationError: Error, Equatable, CustomStringConvertible {
    case invalidField(String)
    case invalidHash(String)
    case hashMismatch(kind: String, id: String, expected: String, actual: String)
    case materialMismatch(String)
    case sourceMismatch(String)

    public var description: String {
        switch self {
        case .invalidField(let reason): "Invalid production content field: \(reason)"
        case .invalidHash(let value): "Invalid sha256 value: \(value)"
        case .hashMismatch(let kind, let id, let expected, let actual):
            "\(kind) \(id) hash mismatch; expected \(expected), found \(actual)"
        case .materialMismatch(let reason): "Blueprint material mismatch: \(reason)"
        case .sourceMismatch(let reason): "Blueprint source mismatch: \(reason)"
        }
    }
}

public enum ProductionContentValidator {
    public static func decodeAndValidateBeadPattern(data: Data) throws -> BeadPatternDefinition {
        let pattern = try JSONDecoder().decode(BeadPatternDefinition.self, from: data)
        try validateDocumentHash(
            data: data,
            excluding: "contentHash",
            actual: pattern.contentHash,
            kind: "BeadPattern",
            id: pattern.assetID
        )
        try validate(beadPattern: pattern)
        return pattern
    }

    public static func decodeAndValidateBlueprint(
        data: Data,
        source: BeadPatternDefinition
    ) throws -> BlueprintDefinition {
        let blueprint = try JSONDecoder().decode(BlueprintDefinition.self, from: data)
        try validateDocumentHash(
            data: data,
            excluding: "blueprintHash",
            actual: blueprint.blueprintHash,
            kind: "Blueprint",
            id: blueprint.blueprintID
        )
        try validate(blueprint: blueprint, source: source)
        return blueprint
    }

    public static func validate(beadPattern: BeadPatternDefinition) throws {
        guard beadPattern.schema == ProductionContentSchema.beadPattern,
              !beadPattern.assetID.isEmpty,
              beadPattern.revision > 0,
              !beadPattern.generator.name.isEmpty,
              !beadPattern.generator.version.isEmpty,
              !beadPattern.provenance.sourceType.isEmpty,
              !beadPattern.provenance.sourceRef.isEmpty,
              beadPattern.provenance.commercialUseCleared else {
            throw ProductionContentValidationError.invalidField("bead header, generator, or provenance")
        }
        try validate(
            grid: beadPattern.grid,
            palette: beadPattern.palette,
            physical: beadPattern.physical
        )
        try requireHash(beadPattern.contentHash)
    }

    public static func validate(
        blueprint: BlueprintDefinition,
        source: BeadPatternDefinition
    ) throws {
        guard blueprint.schema == ProductionContentSchema.blueprint,
              !blueprint.blueprintID.isEmpty,
              !blueprint.artworkID.isEmpty,
              blueprint.revision > 0,
              !blueprint.exportRules.version.isEmpty,
              !blueprint.exportRules.filenameVersion.isEmpty,
              blueprint.exportRules.pixelsPerCell >= 8 else {
            throw ProductionContentValidationError.invalidField("blueprint header or export rules")
        }
        try validate(grid: blueprint.grid, palette: blueprint.palette, physical: blueprint.physical)
        guard blueprint.sourceBeadAsset == BeadAssetReference(
            assetID: source.assetID,
            revision: source.revision,
            contentHash: source.contentHash
        ) else {
            throw ProductionContentValidationError.sourceMismatch("source identity does not resolve")
        }
        guard blueprint.grid == source.grid,
              blueprint.palette == source.palette,
              blueprint.physical == source.physical else {
            throw ProductionContentValidationError.sourceMismatch("grid, palette, or physical data drifted from source")
        }

        let materialIDs = blueprint.materialCounts.map(\.colorId)
        guard Set(materialIDs).count == materialIDs.count,
              blueprint.materialCounts.allSatisfy({ $0.count > 0 }) else {
            throw ProductionContentValidationError.materialMismatch(
                "material color IDs must be unique with positive counts"
            )
        }
        var actualCounts: [String: Int] = [:]
        for index in blueprint.grid.cells where index > 0 {
            let colorID = blueprint.palette[index - 1].colorId
            actualCounts[colorID, default: 0] += 1
        }
        let declaredCounts = Dictionary(
            uniqueKeysWithValues: blueprint.materialCounts.map { ($0.colorId, $0.count) }
        )
        guard actualCounts == declaredCounts else {
            throw ProductionContentValidationError.materialMismatch("declared counts differ from grid")
        }
        guard blueprint.totalBeads == actualCounts.values.reduce(0, +) else {
            throw ProductionContentValidationError.materialMismatch("totalBeads differs from grid")
        }
        let expectedWidth = Double(blueprint.grid.width) * blueprint.physical.beadPitchMm
        let expectedHeight = Double(blueprint.grid.height) * blueprint.physical.beadPitchMm
        guard blueprint.completedSize.widthMm == expectedWidth,
              blueprint.completedSize.heightMm == expectedHeight else {
            throw ProductionContentValidationError.invalidField("completed size differs from grid and bead pitch")
        }
        try requireHash(blueprint.blueprintHash)
        let width = blueprint.grid.width.multipliedReportingOverflow(
            by: blueprint.exportRules.pixelsPerCell
        )
        let height = blueprint.grid.height.multipliedReportingOverflow(
            by: blueprint.exportRules.pixelsPerCell
        )
        guard !width.overflow, !height.overflow else {
            throw ProductionContentValidationError.invalidField("export pixel dimensions overflow")
        }
    }

    private static func validate(
        grid: ProductionGrid,
        palette: [ProductionPaletteEntry],
        physical: ProductionPhysicalSpecification
    ) throws {
        let cellCount = grid.width.multipliedReportingOverflow(by: grid.height)
        guard grid.origin == "top-left", grid.order == "row-major",
              grid.width > 0, grid.height > 0, !cellCount.overflow,
              grid.cells.count == cellCount.partialValue,
              !palette.isEmpty,
              grid.cells.allSatisfy({ (0...palette.count).contains($0) }) else {
            throw ProductionContentValidationError.invalidField("grid dimensions, indexes, order, or palette")
        }
        let colorIDs = palette.map(\.colorId)
        let symbols = palette.map(\.accessibilitySymbol)
        guard Set(colorIDs).count == colorIDs.count,
              colorIDs.allSatisfy({ !$0.isEmpty }),
              Set(symbols).count == symbols.count,
              palette.allSatisfy({ color in
                  !color.name.isEmpty
                      && color.name.values.allSatisfy({ !$0.isEmpty })
                      && color.accessibilitySymbol.count == 1
                      && !color.brand.name.isEmpty
                      && !color.brand.code.isEmpty
                      && !color.brand.swatchVersion.isEmpty
                      && (0...255).contains(color.sRGB8.r)
                      && (0...255).contains(color.sRGB8.g)
                      && (0...255).contains(color.sRGB8.b)
              }) else {
            throw ProductionContentValidationError.invalidField(
                "palette identity, localized name, RGB, brand mapping, or single-grapheme symbol"
            )
        }

        let boardWidth = physical.boardLayout.columns.multipliedReportingOverflow(
            by: physical.boardLayout.boardWidth
        )
        let boardHeight = physical.boardLayout.rows.multipliedReportingOverflow(
            by: physical.boardLayout.boardHeight
        )
        guard physical.beadPitchMm.isFinite, physical.beadPitchMm > 0,
              physical.boardLayout.columns > 0, physical.boardLayout.rows > 0,
              physical.boardLayout.boardWidth > 0, physical.boardLayout.boardHeight > 0,
              !boardWidth.overflow, !boardHeight.overflow,
              boardWidth.partialValue == grid.width,
              boardHeight.partialValue == grid.height else {
            throw ProductionContentValidationError.invalidField(
                "physical specification or board layout does not cover the grid"
            )
        }
    }

    private static func validateDocumentHash(
        data: Data,
        excluding field: String,
        actual: String,
        kind: String,
        id: String
    ) throws {
        try requireHash(actual)
        let canonical = try JCSCanonicalizer.canonicalData(data, removingTopLevelField: field)
        let expected = "sha256:" + SHA256.hexDigest(canonical)
        guard expected == actual else {
            throw ProductionContentValidationError.hashMismatch(
                kind: kind, id: id, expected: expected, actual: actual
            )
        }
    }

    private static func requireHash(_ value: String) throws {
        let suffix = value.dropFirst("sha256:".count)
        guard value.hasPrefix("sha256:"), suffix.count == 64,
              suffix.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ProductionContentValidationError.invalidHash(value)
        }
    }
}
