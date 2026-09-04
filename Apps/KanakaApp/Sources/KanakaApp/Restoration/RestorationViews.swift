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

    @State private var state: ArtworkProductState?
    @State private var errorMessage: String?

    var body: some View {
        let presentation = services.catalog.experience.artwork(artwork.id)
        List {
            if let body = presentation?.body {
                Section("作品档案") {
                    Text(experienceText(body, catalog: services.catalog))
                }
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
                            PuzzleScreen(services: services, fragment: fragment)
                        } label: {
                            FragmentRow(
                                fragment: fragment,
                                presentation: services.catalog.experience.fragment(fragmentID),
                                catalog: services.catalog,
                                state: state
                            )
                        }
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
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        do {
            state = try await services.flow.artworkStates.state(
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
    let state: ArtworkProductState?

    var body: some View {
        let completed = state?.fragments.first(where: { $0.fragmentID == fragment.id })?.isCompleted == true
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Label(
                    experienceTitle(presentation, fallbackID: fragment.id, catalog: catalog),
                    systemImage: completed ? "checkmark.circle.fill" : "square.dashed"
                )
                if let subtitle = presentation?.subtitle {
                    Text(experienceText(subtitle, catalog: catalog))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if completed { Text("已完成").foregroundStyle(.secondary) }
        }
    }
}
#endif
