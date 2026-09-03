#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import Foundation
import KanakaContentKit
import KanakaProductDomain
import KanakaProgress
import KanakaStory
import SwiftUI

@MainActor
final class KanakaAppModel: ObservableObject {
    @Published private(set) var services: KanakaAppServices?
    @Published private(set) var entitlementSnapshot = MuseumEntitlementSnapshot()
    @Published private(set) var startupError: String?
    @Published var presentedError: String?

    private var isLoading = false
    private var entitlementUpdatesTask: Task<Void, Never>?

    deinit {
        entitlementUpdatesTask?.cancel()
    }

    func load() async {
        guard services == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let contentURL = Bundle.module.url(
                forResource: "Content",
                withExtension: nil
            ) else {
                throw AppCompositionError.missingResource("Content")
            }
            guard let entitlementURL = Bundle.module.url(
                forResource: "entitlements",
                withExtension: "json"
            ) else {
                throw AppCompositionError.missingResource("entitlements.json")
            }

            let catalog = try RuntimeContentCatalog.loadValidated(directoryURL: contentURL)
            let progressStore = try SwiftDataProgressStore()
            let storyStore = try SwiftDataStoryStateStore()
            let storyRules = try Museum1StoryRules.make()
            let storyProcessor = StoryEventProcessor(store: storyStore, rules: storyRules)
            let flow = try ProductFlow(
                catalog: catalog,
                progressStore: progressStore,
                storyProcessor: storyProcessor,
                storyMapping: CompletionStoryMapping()
            )
            let entitlementConfiguration = try JSONDecoder().decode(
                EntitlementConfiguration.self,
                from: Data(contentsOf: entitlementURL)
            )
            let entitlementStore = try StoreKitEntitlementStore(
                configuration: entitlementConfiguration
            )
            let value = KanakaAppServices(
                catalog: catalog,
                flow: flow,
                progressStore: progressStore,
                storyStore: storyStore,
                entitlementStore: entitlementStore,
                sessions: ActivePuzzleSessionRegistry(),
                exporter: BlueprintExportService()
            )
            let updates = await entitlementStore.startListening()
            let initialEntitlements = await entitlementStore.refresh()
            _ = try await flow.reconcileStory()
            entitlementSnapshot = initialEntitlements
            services = value
            entitlementUpdatesTask = Task { @MainActor [weak self] in
                for await updatedSnapshot in updates {
                    guard !Task.isCancelled else { return }
                    self?.entitlementSnapshot = updatedSnapshot
                }
            }
        } catch {
            startupError = String(describing: error)
        }
    }

    func handleScenePhase(_ phase: ScenePhase) async {
        guard let services else { return }
        switch phase {
        case .active:
            entitlementSnapshot = await services.entitlementStore.refresh()
            do { _ = try await services.flow.reconcileStory() }
            catch { presentedError = "故事状态恢复失败：\(error)" }
        case .inactive, .background:
            let failures = await services.sessions.flushAll()
            if !failures.isEmpty {
                presentedError = "有 \(failures.count) 个修复会话尚未持久化，将在回到 App 后重试。"
            }
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        guard let services else { return }
        do {
            entitlementSnapshot = try await services.entitlementStore.restorePurchases()
        } catch {
            presentedError = "恢复购买失败：\(error)"
        }
    }

    func purchase(productID: String) async {
        guard let services else { return }
        do {
            let result = try await services.entitlementStore.purchase(productID: productID)
            switch result {
            case .purchased(let snapshot): entitlementSnapshot = snapshot
            case .pending: presentedError = "购买等待批准，StoreKit 确认后会自动刷新权益。"
            case .cancelled: break
            }
        } catch {
            presentedError = "购买失败：\(error)"
        }
    }
}

@MainActor
final class KanakaAppServices {
    let catalog: RuntimeContentCatalog
    let flow: ProductFlow
    let progressStore: SwiftDataProgressStore
    let storyStore: SwiftDataStoryStateStore
    let entitlementStore: StoreKitEntitlementStore
    let sessions: ActivePuzzleSessionRegistry
    let exporter: BlueprintExportService

    init(
        catalog: RuntimeContentCatalog,
        flow: ProductFlow,
        progressStore: SwiftDataProgressStore,
        storyStore: SwiftDataStoryStateStore,
        entitlementStore: StoreKitEntitlementStore,
        sessions: ActivePuzzleSessionRegistry,
        exporter: BlueprintExportService
    ) {
        self.catalog = catalog
        self.flow = flow
        self.progressStore = progressStore
        self.storyStore = storyStore
        self.entitlementStore = entitlementStore
        self.sessions = sessions
        self.exporter = exporter
    }
}

enum AppCompositionError: Error, CustomStringConvertible {
    case missingResource(String)
    case unsupportedEntitlementSchema(String)

    var description: String {
        switch self {
        case .missingResource(let name): "Missing bundled resource: \(name)"
        case .unsupportedEntitlementSchema(let schema):
            "Unsupported entitlement configuration schema: \(schema)"
        }
    }
}

func displayName(_ stableID: String) -> String {
    stableID
        .split(separator: "-")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}
#endif
