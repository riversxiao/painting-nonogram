# KanakaApp Apple 集成边界

此 Swift Package 现在包含 iOS/iPadOS 17 与 macOS 14 的 Apple composition 实现，以及 Linux fallback sentinel。

## 已实现的 Apple 代码路径

- Bundle-backed validated three-Fragment realistic development catalog（`5×5 / 10×10 / 15×15`）；
- `playable-experience-v1` sidecar 驱动的中英文本地化标题、介绍与完成反馈；
- 首次世界观介绍、独立且可跳过的 `5×5` 教学，以及修复室/拼豆工坊初始入口；
- Museum → Gallery → Artwork → Repair Fragment 导航；
- 可操作 `5×5 + 10×10 + 15×15` 三阶段彩色 Nonogram flow：单 Canvas 绘制 clues、格状态、稳定符号、锁定与 stroke preview；平台无关 `BoardGeometry` / `BoardInputSession` 提供一次拖画一个 batch、阈值轴锁、补格、取消、缩放/平移 clamp，继续支持 Undo/Redo、autosave 与 `0/3 → 3/3` 完成反馈；
- exact-current 单快照派生未开始/进行中/已完成，列表提供开始/继续/已完成入口；Fragment region 驱动原创合成港湾作品的渐进恢复预览，退出谜题后的刷新发生在 durable flush/completion 之后；
- 分别使用命名 `KanakaProgress` / `KanakaStory` 配置的 `SwiftDataProgressStore` 与原子 `SwiftDataStoryStateStore`，避免默认持久化文件碰撞；
- scene phase 与离开棋盘时对所有 active controller 执行 `flush()`；
- 外部 `entitlements.json` 商品→Museum 映射、StoreKit 2 verified current entitlements、购买监听、购买与恢复；
- 只接受 `AuthorizedBlueprint` 的 Core Graphics/ImageIO PNG renderer（20 MP ceiling、逐格稳定符号）、材料清单、临时 workspace 与系统分享；
- 档案 milestone、错误状态、Dynamic Type 基础，以及不依赖每格 SwiftUI View 的逻辑光标 accessibility actions。

Bundle 中内容是原创合成、商业使用已清理且明确 non-Canon 的 three-Fragment development pack，不是 Museum 1 正式发布资产，也不代表真实机构、艺术家或馆藏。教学直接使用独立 `GameSession`，完成或跳过都不会写入 Fragment Progress、恢复 Artwork 或提交 Story evidence；首次启动状态单独保存于版本化 UserDefaults 记录。商品配置默认为空；SKU、价格、免费组合继续由外部配置决定。Story completion mapping 对 development pack 保持为空，不冒充 Museum 1 Canon。

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
