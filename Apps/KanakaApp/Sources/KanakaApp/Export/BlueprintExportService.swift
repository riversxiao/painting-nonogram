#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(SwiftUI)
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import KanakaProductDomain
import UniformTypeIdentifiers

actor BlueprintExportService {
    private let fileManager = FileManager.default

    func export(_ authorized: AuthorizedBlueprint) throws -> [URL] {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("KanakaExport-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let pngURL = directory.appendingPathComponent(authorized.exportPlan.filename)
            try BlueprintPNGRenderer.render(authorized, to: pngURL)
            let materialsURL = directory.appendingPathComponent("materials.txt")
            try materialsText(authorized).write(
                to: materialsURL,
                atomically: true,
                encoding: .utf8
            )
            return [pngURL, materialsURL]
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    func removeWorkspace(containing urls: [URL]) {
        guard let directory = urls.first?.deletingLastPathComponent(),
              directory.lastPathComponent.hasPrefix("KanakaExport-") else { return }
        try? fileManager.removeItem(at: directory)
    }

    private func materialsText(_ authorized: AuthorizedBlueprint) -> String {
        let blueprint = authorized.blueprint
        var lines = [
            "Blueprint: \(blueprint.blueprintID) r\(blueprint.revision)",
            "Hash: \(blueprint.blueprintHash)",
            "Completed size: \(blueprint.completedSize.widthMm) × \(blueprint.completedSize.heightMm) mm",
            "Total beads: \(blueprint.totalBeads)",
            "",
            "Materials",
        ]
        for material in blueprint.materialCounts {
            let palette = blueprint.palette.first { $0.colorId == material.colorId }
            lines.append([
                palette?.name["en"] ?? material.colorId,
                palette?.brand.name ?? "—",
                palette?.brand.code ?? "—",
                palette?.brand.swatchVersion ?? "—",
                String(material.count),
            ].joined(separator: " | "))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

enum BlueprintPNGRenderer {
    private static let maximumPixels = 20_000_000

    static func render(_ authorized: AuthorizedBlueprint, to url: URL) throws {
        let blueprint = authorized.blueprint
        let gridWidth = authorized.exportPlan.pixelWidth
        let gridHeight = authorized.exportPlan.pixelHeight
        let labelMargin = blueprint.exportRules.includeCoordinates ? 32 : 0
        let legendWidth = blueprint.exportRules.includeLegend ? 220 : 0
        let width = try checkedAdd(labelMargin, gridWidth, legendWidth)
        let height = try checkedAdd(labelMargin, gridHeight)
        let pixels = width.multipliedReportingOverflow(by: height)
        guard width > 0, height > 0, !pixels.overflow,
              pixels.partialValue <= maximumPixels else {
            throw ExportError.pixelBudgetExceeded
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ExportError.contextCreationFailed
        }
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let cell = blueprint.exportRules.pixelsPerCell
        for row in 0..<blueprint.grid.height {
            for column in 0..<blueprint.grid.width {
                let paletteIndex = blueprint.grid.cells[row * blueprint.grid.width + column]
                guard (0...blueprint.palette.count).contains(paletteIndex) else {
                    throw ExportError.invalidPaletteIndex(paletteIndex)
                }
                if paletteIndex > 0 {
                    let rgb = blueprint.palette[paletteIndex - 1].sRGB8
                    context.setFillColor(CGColor(
                        red: CGFloat(rgb.r) / 255,
                        green: CGFloat(rgb.g) / 255,
                        blue: CGFloat(rgb.b) / 255,
                        alpha: 1
                    ))
                    let rect = CGRect(
                        x: labelMargin + column * cell,
                        y: height - labelMargin - (row + 1) * cell,
                        width: cell,
                        height: cell
                    )
                    context.fill(rect)
                    let luminance = 0.2126 * Double(rgb.r)
                        + 0.7152 * Double(rgb.g)
                        + 0.0722 * Double(rgb.b)
                    context.setAllowsAntialiasing(true)
                    context.setShouldAntialias(true)
                    drawText(
                        blueprint.palette[paletteIndex - 1].accessibilitySymbol,
                        x: Int(rect.minX) + max(1, cell / 5),
                        y: Int(rect.minY) + max(1, cell / 5),
                        fontSize: max(5, min(14, CGFloat(cell) * 0.62)),
                        color: luminance < 140
                            ? CGColor(gray: 1, alpha: 1)
                            : CGColor(gray: 0, alpha: 1),
                        context: context
                    )
                    context.setShouldAntialias(false)
                    context.setAllowsAntialiasing(false)
                }
            }
        }

        context.setStrokeColor(CGColor(gray: 0.25, alpha: 1))
        context.setLineWidth(1)
        for column in 0...blueprint.grid.width {
            let x = labelMargin + column * cell
            context.move(to: CGPoint(x: x, y: height - labelMargin))
            context.addLine(to: CGPoint(x: x, y: height - labelMargin - gridHeight))
        }
        for row in 0...blueprint.grid.height {
            let y = height - labelMargin - row * cell
            context.move(to: CGPoint(x: labelMargin, y: y))
            context.addLine(to: CGPoint(x: labelMargin + gridWidth, y: y))
        }
        context.strokePath()

        if blueprint.exportRules.includeCoordinates {
            for column in 0..<blueprint.grid.width {
                drawText("\(column + 1)", x: labelMargin + column * cell + 2, y: height - 22, context: context)
            }
            for row in 0..<blueprint.grid.height {
                drawText("\(row + 1)", x: 4, y: height - labelMargin - (row + 1) * cell + 2, context: context)
            }
        }
        if blueprint.exportRules.includeLegend {
            var y = height - 24
            for item in blueprint.palette {
                drawText(
                    "\(item.accessibilitySymbol)  \(item.brand.code)  \(item.name["en"] ?? item.colorId)",
                    x: labelMargin + gridWidth + 12,
                    y: y,
                    context: context
                )
                y -= 22
            }
        }

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
              ) else {
            throw ExportError.destinationCreationFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.encodingFailed
        }
    }

    private static func drawText(
        _ text: String,
        x: Int,
        y: Int,
        fontSize: CGFloat = 12,
        color: CGColor = CGColor(gray: 0.1, alpha: 1),
        context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(
                "Helvetica" as CFString,
                fontSize,
                nil
            ),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private static func checkedAdd(_ values: Int...) throws -> Int {
        var result = 0
        for value in values {
            let next = result.addingReportingOverflow(value)
            guard !next.overflow else { throw ExportError.pixelBudgetExceeded }
            result = next.partialValue
        }
        return result
    }
}

enum ExportError: Error {
    case pixelBudgetExceeded
    case contextCreationFailed
    case invalidPaletteIndex(Int)
    case destinationCreationFailed
    case encodingFailed
}
#endif
