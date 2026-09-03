import KanakaProductDomain

#if canImport(SwiftUI)
import SwiftUI

@main
struct KanakaApp: App {
    var body: some Scene {
        WindowGroup {
            KanakaRootView()
        }
    }
}

private enum KanakaSection: String, CaseIterable, Identifiable {
    case restoration = "修复室"
    case workshop = "拼豆工坊"
    case archive = "档案"
    case settings = "设置"

    var id: Self { self }
    var systemImage: String {
        switch self {
        case .restoration: "paintbrush.pointed"
        case .workshop: "square.grid.3x3.fill"
        case .archive: "archivebox"
        case .settings: "gearshape"
        }
    }
}

private struct KanakaRootView: View {
    @State private var selection: KanakaSection? = .restoration

    var body: some View {
        NavigationSplitView {
            List(KanakaSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("文明修复署")
        } detail: {
            switch selection ?? .restoration {
            case .restoration:
                ProductBoundaryPlaceholder(
                    title: "修复室",
                    subtitle: "Museum → Gallery → Artwork → Repair Fragment",
                    symbol: "paintbrush.pointed"
                )
            case .workshop:
                ProductBoundaryPlaceholder(
                    title: "拼豆工坊",
                    subtitle: "Museum 蓝图、材料清单与导出",
                    symbol: "square.grid.3x3.fill"
                )
            case .archive:
                ProductBoundaryPlaceholder(
                    title: "档案",
                    subtitle: "修复证据与故事里程碑",
                    symbol: "archivebox"
                )
            case .settings:
                ProductBoundaryPlaceholder(
                    title: "设置",
                    subtitle: "音频、触觉、无障碍与隐私",
                    symbol: "gearshape"
                )
            }
        }
    }
}

private struct ProductBoundaryPlaceholder: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: symbol,
            description: Text(subtitle)
        )
        .navigationTitle(title)
    }
}

#else

/// Linux build sentinel. The actual iOS/iPadOS executable is compiled by Xcode with SwiftUI.
@main
enum KanakaAppBuildSentinel {
    static func main() {
        print("KanakaApp Apple shell boundary compiled; SwiftUI requires an Apple SDK")
    }
}

#endif
