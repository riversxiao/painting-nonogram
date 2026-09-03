#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaContentKit
import KanakaProductDomain
import SwiftUI

struct WorkshopHomeView: View {
    let services: KanakaAppServices

    var body: some View {
        List(services.catalog.museums.keys.sorted(), id: \.self) { museumID in
            if let museum = services.catalog.museums[museumID] {
                Section(displayName(museum.id)) {
                    ForEach(artworkIDs(in: museum), id: \.self) { artworkID in
                        NavigationLink {
                            BlueprintDetailView(services: services, artworkID: artworkID)
                        } label: {
                            Label(displayName(artworkID), systemImage: "square.grid.3x3")
                        }
                    }
                }
            }
        }
        .navigationTitle("拼豆工坊")
    }

    private func artworkIDs(in museum: MuseumDefinition) -> [String] {
        museum.galleryIDs.flatMap { galleryID in
            services.catalog.galleries[galleryID]?.artworkIDs ?? []
        }
    }
}

private struct BlueprintDetailView: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let services: KanakaAppServices
    let artworkID: String

    @State private var blueprint: AuthorizedBlueprint?
    @State private var exportURLs: [URL] = []
    @State private var errorMessage: String?
    @State private var isExporting = false
    @State private var showShare = false

    var body: some View {
        Group {
            if let blueprint {
                List {
                    Section("制作网格") {
                        BlueprintGridView(blueprint: blueprint.blueprint)
                        Text("\(blueprint.blueprint.completedSize.widthMm, specifier: "%.1f") × \(blueprint.blueprint.completedSize.heightMm, specifier: "%.1f") mm")
                        Text("共 \(blueprint.exportPlan.totalBeads) 颗")
                    }
                    Section("材料") {
                        ForEach(blueprint.blueprint.materialCounts, id: \.colorId) { material in
                            let palette = blueprint.blueprint.palette.first {
                                $0.colorId == material.colorId
                            }
                            HStack {
                                Text(palette?.name["zh-Hans"] ?? palette?.name["en"] ?? material.colorId)
                                Spacer()
                                Text("\(palette?.brand.code ?? "—") · \(material.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        Button {
                            Task { await export(blueprint) }
                        } label: {
                            Label("生成 PNG 与材料清单", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isExporting)
                    }
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Blueprint 尚未解锁",
                    systemImage: "lock.fill",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("正在验证使用权限…")
            }
        }
        .navigationTitle(displayName(artworkID))
        .task { await open() }
#if canImport(UIKit)
        .sheet(isPresented: $showShare, onDismiss: cleanup) {
            ActivityShareView(items: exportURLs)
        }
#elseif canImport(AppKit)
        .sheet(isPresented: $showShare, onDismiss: cleanup) {
            VStack(spacing: 16) {
                Text("导出文件").font(.headline)
                ForEach(exportURLs, id: \.self) { url in
                    ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "square.and.arrow.up") }
                }
            }
            .padding()
        }
#endif
    }

    private func open() async {
        do {
            blueprint = try await services.flow.blueprints.openBlueprint(
                artworkID: artworkID,
                entitlements: appModel.entitlementSnapshot
            )
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func export(_ authorized: AuthorizedBlueprint) async {
        isExporting = true
        defer { isExporting = false }
        do {
            exportURLs = try await services.exporter.export(authorized)
            showShare = true
        } catch {
            errorMessage = "导出失败：\(error)"
        }
    }

    private func cleanup() {
        let urls = exportURLs
        exportURLs = []
        Task { await services.exporter.removeWorkspace(containing: urls) }
    }
}

private struct BlueprintGridView: View {
    let blueprint: BlueprintDefinition
    private let size: CGFloat = 32

    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<blueprint.grid.height, id: \.self) { row in
                GridRow {
                    ForEach(0..<blueprint.grid.width, id: \.self) { column in
                        let index = blueprint.grid.cells[row * blueprint.grid.width + column]
                        ZStack {
                            Rectangle()
                                .fill(color(index))
                            if index > 0 {
                                Text(blueprint.palette[index - 1].accessibilitySymbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(symbolColor(index))
                            }
                        }
                        .frame(width: size, height: size)
                        .overlay(Rectangle().stroke(.secondary, lineWidth: 0.5))
                        .accessibilityLabel(accessibilityLabel(row: row, column: column, index: index))
                    }
                }
            }
        }
    }

    private func color(_ index: Int) -> Color {
        guard index > 0 else { return .white }
        return Color(sRGB8: blueprint.palette[index - 1].sRGB8)
    }

    private func symbolColor(_ index: Int) -> Color {
        guard index > 0 else { return .primary }
        let rgb = blueprint.palette[index - 1].sRGB8
        let luminance = 0.2126 * Double(rgb.r) + 0.7152 * Double(rgb.g) + 0.0722 * Double(rgb.b)
        return luminance < 140 ? .white : .black
    }

    private func accessibilityLabel(row: Int, column: Int, index: Int) -> String {
        guard index > 0 else { return "第 \(row + 1) 行第 \(column + 1) 列，空" }
        let item = blueprint.palette[index - 1]
        return "第 \(row + 1) 行第 \(column + 1) 列，\(item.colorId)，符号 \(item.accessibilitySymbol)"
    }
}
#endif
