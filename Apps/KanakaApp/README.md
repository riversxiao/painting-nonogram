# KanakaApp 接入边界

此 Swift Package 建立 iOS/iPadOS 17 的 SwiftUI composition root 与自适应 `NavigationSplitView` 骨架，并依赖平台无关的 `KanakaProductDomain`。

Apple 环境中的最终 composition root 应注入：

- Bundle-backed `RuntimeContentCatalog`；
- `SwiftDataProgressStore` 与 StoryState 持久化 adapter；
- StoreKit 2 已验证交易监听、恢复与 Museum entitlement snapshot；
- Core Graphics/ImageIO Blueprint PNG renderer；
- 临时导出 workspace 与系统 Share Sheet；
- Scene phase 后台 `flush()`；
- OSLog、MetricKit 与无障碍配置。

本仓库当前 Linux gate 只编译 fallback sentinel，证明 App 对领域层的依赖方向。SwiftUI、StoreKit、SwiftData Apple 分支、Core Graphics 输出与真机性能必须在 Xcode/iOS 17 或 macOS 14 SDK 下继续验证。SKU、价格、免费组合和 legacy revision 玩家政策仍保持外部配置，不在 App 骨架中硬编码。
