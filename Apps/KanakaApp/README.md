# KanakaApp Apple 集成边界

此 Swift Package 现在包含 iOS/iPadOS 17 与 macOS 14 的 Apple composition 实现，以及 Linux fallback sentinel。

## 已实现的 Apple 代码路径

- Bundle-backed validated two-Fragment development catalog；
- `playable-experience-v1` sidecar 驱动的中英文本地化标题、介绍与完成反馈；
- 首次世界观介绍、独立且可跳过的 `5×5` 教学，以及修复室/拼豆工坊初始入口；
- Museum → Gallery → Artwork → Repair Fragment 导航；
- 可操作 `5×5 + 1×1` 两阶段彩色 Nonogram reference flow，含颜色符号、排除/擦除、Undo/Redo、autosave 与中间/最终完成反馈；
- 分别使用命名 `KanakaProgress` / `KanakaStory` 配置的 `SwiftDataProgressStore` 与原子 `SwiftDataStoryStateStore`，避免默认持久化文件碰撞；
- scene phase 与离开棋盘时对所有 active controller 执行 `flush()`；
- 外部 `entitlements.json` 商品→Museum 映射、StoreKit 2 verified current entitlements、购买监听、购买与恢复；
- 只接受 `AuthorizedBlueprint` 的 Core Graphics/ImageIO PNG renderer（20 MP ceiling、逐格稳定符号）、材料清单、临时 workspace 与系统分享；
- 档案 milestone、错误状态、Dynamic Type 基础和逐格非颜色 accessibility labels。

Bundle 中内容是 synthetic two-Fragment development fixture，不是 Museum 1 正式发布资产。教学直接使用独立 `GameSession`，完成或跳过都不会写入 Fragment Progress、恢复 Artwork 或提交 Story evidence；首次启动状态单独保存于版本化 UserDefaults 记录。商品配置默认为空；SKU、价格、免费组合继续由外部配置决定。Story completion mapping 对 development fixture 保持为空，不冒充 Museum 1 Canon。

## 仍需 Apple/Xcode 验证

Linux 的 `make validate-app` 只校验 Bundle catalog，并编译/运行 fallback sentinel。以下代码在 Linux 被条件编译排除，尚不能声称通过：

- SwiftUI iPhone/iPad/macOS 编译、导航、布局和手势；
- SwiftData reopen、save rollback、并发 transaction visibility 与 migration；
- StoreKit Configuration 购买、pending、revocation、expiration、upgrade 和离线恢复；
- PNG golden pixels、坐标/legend 排版、内存上限和实物打印；
- UIKit Share Sheet iPad presentation 与 macOS ShareLink 生命周期；
- scene suspension/background time、VoiceOver/Voice Control/Switch Control；
- 25×25 production board 的 Canvas/虚拟化性能与真机 60 fps；
- OSLog、MetricKit、PrivacyInfo 与签名 iOS App host target。

当前 Swift Package 提供可组合代码和资源边界；安装到模拟器/真机仍需由 Xcode App target 承载并运行上述 gate。
