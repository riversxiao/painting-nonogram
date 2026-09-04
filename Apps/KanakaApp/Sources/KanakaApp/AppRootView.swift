#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaContentKit
import SwiftUI

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

struct AppRootView: View {
    @EnvironmentObject private var model: KanakaAppModel

    var body: some View {
        Group {
            if let services = model.services {
                PlayableExperienceGate(services: services)
            } else if let startupError = model.startupError {
                ContentUnavailableView(
                    "无法启动文明修复署",
                    systemImage: "exclamationmark.triangle",
                    description: Text(startupError)
                )
            } else {
                ProgressView("正在验证内容与恢复进度…")
            }
        }
        .alert("需要处理", isPresented: Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("好") { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "")
        }
    }
}

struct MainAppShell: View {
    let services: KanakaAppServices
    @State private var selection: KanakaSection?

    init(services: KanakaAppServices, initialRoute: PlayableExperienceRoute) {
        self.services = services
        _selection = State(initialValue: initialRoute == .restoration ? .restoration : .workshop)
    }

    var body: some View {
        NavigationSplitView {
            List(KanakaSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("文明修复署")
        } detail: {
            NavigationStack {
                switch selection ?? .restoration {
                case .restoration: RestorationHomeView(services: services)
                case .workshop: WorkshopHomeView(services: services)
                case .archive: ArchiveView(services: services)
                case .settings: SettingsView(services: services)
                }
            }
        }
    }
}
#endif
