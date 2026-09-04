#if canImport(SwiftUI) && canImport(SwiftData) && canImport(StoreKit)
import KanakaStory
import SwiftUI

struct ArchiveView: View {
    let services: KanakaAppServices
    @State private var storyState: StoryState?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let storyState {
                Section("故事里程碑") {
                    ForEach(StoryMilestoneID.allCases, id: \.self) { milestone in
                        Label(
                            displayName(milestone.rawValue),
                            systemImage: storyState.hasAchieved(milestone)
                                ? "checkmark.seal.fill" : "seal"
                        )
                    }
                }
                Section("审计") {
                    Text("已接受 \(storyState.acceptedEvidence.count) 条 Canon evidence")
                }
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("档案")
        .task {
            do { storyState = try await services.flow.storyState() }
            catch { errorMessage = String(describing: error) }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: KanakaAppModel
    let services: KanakaAppServices
    @State private var products: [StoreProductPresentation] = []

    var body: some View {
        List {
            Section("Blueprint 权益") {
                if model.entitlementSnapshot.museumIDs.isEmpty {
                    Text("当前没有 Museum 蓝图库权益")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.entitlementSnapshot.museumIDs.sorted(), id: \.self) {
                        Label(displayName($0), systemImage: "checkmark.seal.fill")
                    }
                }
                Button("恢复购买") { Task { await model.restorePurchases() } }
            }

            if !products.isEmpty {
                Section("可用项目") {
                    ForEach(products) { product in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.name)
                                Text(product.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice)
                            Button("购买") {
                                Task { await model.purchase(productID: product.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("无障碍") {
                Label("颜色同时使用稳定名称与符号编码", systemImage: "accessibility")
                Label("棋盘格提供行、列、状态与颜色语义", systemImage: "rectangle.grid.3x2")
                Label("支持 Dynamic Type 与系统 Reduce Motion", systemImage: "textformat.size")
            }

            Section("体验") {
                Button("重新运行首次启动与教学") {
                    Task { await model.resetPlayableExperience() }
                }
            }

            Section("数据边界") {
                Text("进度、Story 与已验证交易分别持久化；购买不会完成谜题或推进 Story。")
                    .font(.footnote)
            }
        }
        .navigationTitle("设置")
        .task { await loadProducts() }
    }

    private func loadProducts() async {
        do {
            products = try await services.entitlementStore.products().map {
                StoreProductPresentation(
                    id: $0.id,
                    name: $0.displayName,
                    description: $0.description,
                    displayPrice: $0.displayPrice
                )
            }
        } catch {
            model.presentedError = "无法加载 StoreKit 项目：\(error)"
        }
    }
}

private struct StoreProductPresentation: Identifiable {
    let id: String
    let name: String
    let description: String
    let displayPrice: String
}
#endif
