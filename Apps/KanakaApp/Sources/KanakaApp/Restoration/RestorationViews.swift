#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaContentKit
import KanakaProductDomain
import SwiftUI

struct RestorationHomeView: View {
    let services: KanakaAppServices

    var body: some View {
        List(services.catalog.museums.keys.sorted(), id: \.self) { museumID in
            if let museum = services.catalog.museums[museumID] {
                let presentation = services.catalog.experience.museum(museumID)
                NavigationLink {
                    MuseumView(services: services, museum: museum)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            experienceTitle(presentation, fallbackID: museumID, catalog: services.catalog),
                            systemImage: "building.columns"
                        )
                        if let subtitle = presentation?.subtitle {
                            Text(experienceText(subtitle, catalog: services.catalog))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("修复室")
        .overlay {
            if services.catalog.museums.isEmpty {
                ContentUnavailableView("暂无博物馆", systemImage: "building.columns")
            }
        }
    }
}

private struct MuseumView: View {
    let services: KanakaAppServices
    let museum: MuseumDefinition

    var body: some View {
        let museumPresentation = services.catalog.experience.museum(museum.id)
        List {
            if let body = museumPresentation?.body {
                Section("馆藏说明") {
                    Text(experienceText(body, catalog: services.catalog))
                }
            }
            Section("展厅") {
                ForEach(museum.galleryIDs, id: \.self) { galleryID in
                    if let gallery = services.catalog.galleries[galleryID] {
                        let presentation = services.catalog.experience.gallery(galleryID)
                        NavigationLink {
                            GalleryView(services: services, gallery: gallery)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(experienceTitle(
                                    presentation,
                                    fallbackID: galleryID,
                                    catalog: services.catalog
                                ))
                                if let subtitle = presentation?.subtitle {
                                    Text(experienceText(subtitle, catalog: services.catalog))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(experienceTitle(
            museumPresentation,
            fallbackID: museum.id,
            catalog: services.catalog
        ))
    }
}

private struct GalleryView: View {
    let services: KanakaAppServices
    let gallery: GalleryDefinition

    var body: some View {
        let galleryPresentation = services.catalog.experience.gallery(gallery.id)
        List {
            if let body = galleryPresentation?.body {
                Section("章节背景") {
                    Text(experienceText(body, catalog: services.catalog))
                }
            }
            Section("作品") {
                ForEach(gallery.artworkIDs, id: \.self) { artworkID in
                    if let artwork = services.catalog.artworks[artworkID] {
                        let presentation = services.catalog.experience.artwork(artworkID)
                        NavigationLink {
                            ArtworkView(services: services, artwork: artwork)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(
                                    experienceTitle(
                                        presentation,
                                        fallbackID: artworkID,
                                        catalog: services.catalog
                                    ),
                                    systemImage: "photo.artframe"
                                )
                                if let subtitle = presentation?.subtitle {
                                    Text(experienceText(subtitle, catalog: services.catalog))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(experienceTitle(
            galleryPresentation,
            fallbackID: gallery.id,
            catalog: services.catalog
        ))
    }
}

struct ArtworkView: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let services: KanakaAppServices
    let artwork: ArtworkDefinition

    @State private var snapshot: ArtworkRestorationSnapshot?
    @State private var progressRevision = 0
    @State private var errorMessage: String?

    var body: some View {
        let presentation = services.catalog.experience.artwork(artwork.id)
        let state = snapshot?.artworkState
        List {
            if let body = presentation?.body {
                Section("作品档案") {
                    Text(experienceText(body, catalog: services.catalog))
                }
            }
            Section("渐进恢复") {
                ProgressiveRestorationPreview(
                    fragments: orderedFragments,
                    snapshot: snapshot
                )
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }
            Section("修复进度") {
                if let state {
                    ProgressView(value: Double(state.completedCount), total: Double(state.totalCount))
                    Text("\(state.completedCount) / \(state.totalCount) 个修复片段")
                    if state.access.artworkRestored {
                        Label("整幅作品已修复", systemImage: "seal.fill")
                            .foregroundStyle(.green)
                        if let completionBody = presentation?.completionBody {
                            Text(experienceText(completionBody, catalog: services.catalog))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ProgressView()
                }
            }

            Section("修复片段") {
                ForEach(artwork.repairFragmentIDs, id: \.self) { fragmentID in
                    if let fragment = services.catalog.fragments[fragmentID] {
                        NavigationLink {
                            PuzzleScreen(
                                services: services,
                                fragment: fragment,
                                progressDidChange: { progressRevision &+= 1 }
                            )
                        } label: {
                            FragmentRow(
                                fragment: fragment,
                                presentation: services.catalog.experience.fragment(fragmentID),
                                catalog: services.catalog,
                                status: status(for: fragmentID)
                            )
                        }
                        .disabled(snapshot == nil)
                    }
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(experienceTitle(
            presentation,
            fallbackID: artwork.id,
            catalog: services.catalog
        ))
        .task(id: progressRevision) { await reload() }
        .refreshable { await reload() }
    }

    private var orderedFragments: [RepairFragmentDefinition] {
        artwork.repairFragmentIDs.compactMap { services.catalog.fragments[$0] }
    }

    private func status(for fragmentID: String) -> FragmentRestorationStatus? {
        snapshot?.fragments.first(where: { $0.fragmentID == fragmentID })?.status
    }

    private func reload() async {
        do {
            snapshot = try await services.flow.artworkStates.restorationSnapshot(
                artworkID: artwork.id,
                entitlements: appModel.entitlementSnapshot
            )
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

private struct FragmentRow: View {
    let fragment: RepairFragmentDefinition
    let presentation: ExperienceEntityPresentation?
    let catalog: RuntimeContentCatalog
    let status: FragmentRestorationStatus?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Label(
                    experienceTitle(presentation, fallbackID: fragment.id, catalog: catalog),
                    systemImage: statusSymbol
                )
                if let subtitle = presentation?.subtitle {
                    Text(experienceText(subtitle, catalog: catalog))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(actionLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(actionColor)
        }
        .accessibilityValue(actionLabel)
    }

    private var statusSymbol: String {
        switch status {
        case .some(.notStarted): "square.dashed"
        case .some(.inProgress): "arrow.clockwise.circle.fill"
        case .some(.completed): "checkmark.circle.fill"
        case .none: "hourglass"
        }
    }

    private var actionLabel: String {
        switch status {
        case .some(.notStarted): "开始"
        case .some(.inProgress): "继续"
        case .some(.completed): "已完成"
        case .none: "读取中"
        }
    }

    private var actionColor: Color {
        switch status {
        case .some(.notStarted), .none: .secondary
        case .some(.inProgress): .orange
        case .some(.completed): .green
        }
    }
}

private struct ProgressiveRestorationPreview: View {
    let fragments: [RepairFragmentDefinition]
    let snapshot: ArtworkRestorationSnapshot?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SyntheticHarborArtwork()
                ForEach(fragments, id: \.id) { fragment in
                    regionOverlay(status(for: fragment.id))
                        .frame(
                            width: proxy.size.width * fragment.region.width,
                            height: proxy.size.height * fragment.region.height
                        )
                        .position(
                            x: proxy.size.width * (fragment.region.x + fragment.region.width / 2),
                            y: proxy.size.height * (fragment.region.y + fragment.region.height / 2)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.secondary.opacity(0.5)))
        }
        .frame(height: 190)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("合成作品渐进恢复预览")
        .accessibilityValue(accessibilityProgress)
    }

    private func status(for fragmentID: String) -> FragmentRestorationStatus? {
        snapshot?.fragments.first(where: { $0.fragmentID == fragmentID })?.status
    }

    @ViewBuilder
    private func regionOverlay(_ status: FragmentRestorationStatus?) -> some View {
        switch status {
        case .none:
            ZStack {
                Rectangle().fill(.black.opacity(0.82))
                ProgressView().tint(.white)
            }
            .overlay(Rectangle().stroke(.white.opacity(0.25)))
        case .some(.notStarted):
            ZStack {
                Rectangle().fill(.black.opacity(0.72))
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .overlay(Rectangle().stroke(.white.opacity(0.25)))
        case .some(.inProgress):
            ZStack {
                Rectangle().fill(.orange.opacity(0.32))
                Image(systemName: "arrow.clockwise")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .overlay(Rectangle().stroke(.orange, lineWidth: 2))
        case .some(.completed):
            Rectangle()
                .fill(.clear)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.white, .green)
                        .padding(6)
                }
                .overlay(Rectangle().stroke(.green.opacity(0.75), lineWidth: 2))
        }
    }

    private var accessibilityProgress: String {
        let statuses = fragments.map { status(for: $0.id) }
        let completed = statuses.compactMap { $0 }.filter(\.isCompleted).count
        let inProgress = statuses.compactMap { $0 }.filter {
            if case .inProgress = $0 { return true }
            return false
        }.count
        let unavailable = statuses.filter { $0 == nil }.count
        if unavailable > 0 {
            return "修复进度读取中"
        }
        return "已完成 \(completed) / \(fragments.count)，进行中 \(inProgress)"
    }
}

private struct SyntheticHarborArtwork: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bounds),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.06, green: 0.10, blue: 0.20),
                        Color(red: 0.18, green: 0.26, blue: 0.42),
                        Color(red: 0.80, green: 0.36, blue: 0.33),
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )

            var beam = Path()
            beam.move(to: CGPoint(x: size.width * 0.48, y: size.height * 0.27))
            beam.addLine(to: CGPoint(x: size.width * 0.12, y: size.height * 0.14))
            beam.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.35))
            beam.closeSubpath()
            context.fill(beam, with: .color(.yellow.opacity(0.48)))

            let tower = CGRect(
                x: size.width * 0.43,
                y: size.height * 0.30,
                width: size.width * 0.14,
                height: size.height * 0.52
            )
            context.fill(Path(tower), with: .color(Color(red: 0.13, green: 0.20, blue: 0.33)))
            context.fill(
                Path(ellipseIn: CGRect(
                    x: size.width * 0.45,
                    y: size.height * 0.23,
                    width: size.width * 0.10,
                    height: size.height * 0.13
                )),
                with: .color(Color(red: 0.96, green: 0.75, blue: 0.28))
            )

            for index in 0..<4 {
                let y = size.height * (0.73 + Double(index) * 0.065)
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: y))
                wave.addCurve(
                    to: CGPoint(x: size.width, y: y),
                    control1: CGPoint(x: size.width * 0.28, y: y - 10),
                    control2: CGPoint(x: size.width * 0.68, y: y + 10)
                )
                context.stroke(wave, with: .color(.white.opacity(0.38)), lineWidth: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
#endif
