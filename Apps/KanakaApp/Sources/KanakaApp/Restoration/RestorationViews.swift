#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaContentKit
import KanakaProductDomain
import SwiftUI

struct RestorationHomeView: View {
    let services: KanakaAppServices

    var body: some View {
        List(services.catalog.museums.keys.sorted(), id: \.self) { museumID in
            if let museum = services.catalog.museums[museumID] {
                NavigationLink {
                    MuseumView(services: services, museum: museum)
                } label: {
                    Label(displayName(museum.id), systemImage: "building.columns")
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
        List(museum.galleryIDs, id: \.self) { galleryID in
            if let gallery = services.catalog.galleries[galleryID] {
                NavigationLink {
                    GalleryView(services: services, gallery: gallery)
                } label: {
                    VStack(alignment: .leading) {
                        Text(displayName(gallery.id))
                        Text(gallery.chapterNarrativeID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(displayName(museum.id))
    }
}

private struct GalleryView: View {
    let services: KanakaAppServices
    let gallery: GalleryDefinition

    var body: some View {
        List(gallery.artworkIDs, id: \.self) { artworkID in
            if let artwork = services.catalog.artworks[artworkID] {
                NavigationLink {
                    ArtworkView(services: services, artwork: artwork)
                } label: {
                    Label(displayName(artwork.id), systemImage: "photo.artframe")
                }
            }
        }
        .navigationTitle(displayName(gallery.id))
    }
}

struct ArtworkView: View {
    @EnvironmentObject private var appModel: KanakaAppModel
    let services: KanakaAppServices
    let artwork: ArtworkDefinition

    @State private var state: ArtworkProductState?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("修复进度") {
                if let state {
                    ProgressView(value: Double(state.completedCount), total: Double(state.totalCount))
                    Text("\(state.completedCount) / \(state.totalCount) 个修复片段")
                    if state.access.artworkRestored {
                        Label("整幅作品已修复", systemImage: "seal.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    ProgressView()
                }
            }

            Section("Repair Fragments") {
                ForEach(artwork.repairFragmentIDs, id: \.self) { fragmentID in
                    if let fragment = services.catalog.fragments[fragmentID] {
                        NavigationLink {
                            PuzzleScreen(services: services, fragment: fragment)
                        } label: {
                            FragmentRow(fragment: fragment, state: state)
                        }
                    }
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle(displayName(artwork.id))
        .task { await reload() }
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
    let state: ArtworkProductState?

    var body: some View {
        let completed = state?.fragments.first(where: { $0.fragmentID == fragment.id })?.isCompleted == true
        HStack {
            Label(displayName(fragment.id), systemImage: completed ? "checkmark.circle.fill" : "square.dashed")
            Spacer()
            if completed { Text("已完成").foregroundStyle(.secondary) }
        }
    }
}
#endif
