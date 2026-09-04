import KanakaProductDomain

#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import SwiftUI

@main
struct KanakaApp: App {
    @StateObject private var model = KanakaAppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(model)
                .task { await model.load() }
                .onChange(of: scenePhase) { _, phase in
                    Task { await model.handleScenePhase(phase) }
                }
        }
    }
}

#else

/// Linux build sentinel. The actual iOS/iPadOS executable is compiled by Xcode with Apple SDKs.
@main
enum KanakaAppBuildSentinel {
    static func main() {
        print("KanakaApp integration boundary compiled; Apple UI/adapters require Xcode validation")
    }
}

#endif
